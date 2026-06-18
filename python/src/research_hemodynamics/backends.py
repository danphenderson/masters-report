"""Backend adapters for NumPy, Torch, SciPy, and Julia/SciML reference runs."""

from __future__ import annotations

import csv
import math
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter
from typing import Any

import numpy as np

from .logging import event_fields, get_logger
from .numerics import (
    AREA_FLOOR,
    AREA_LIMITER_FLOOR,
    RunRequest,
    SimulationResult,
    compare_metrics,
    dt_stats,
    grid,
    initial_state,
    pressure,
    resolve_dtype_name,
    rhs,
    run_native,
    save_times,
)

_LOG = get_logger(__name__)


class BackendUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class DeviceInfo:
    name: str
    available: bool
    backend: str
    reason: str = ""


def detect_devices() -> list[DeviceInfo]:
    devices = [DeviceInfo("cpu", True, "numpy")]
    try:
        import torch  # type: ignore[import-not-found]
    except Exception as exc:
        devices.append(DeviceInfo("mps", False, "torch", f"torch unavailable: {exc}"))
        devices.append(DeviceInfo("cuda", False, "torch", "torch unavailable"))
        _LOG.debug(
            "device probe completed",
            extra=event_fields(
                event="device_probe",
                stage="detect_devices",
                backend="torch",
                status="partial",
                rows=len(devices),
                reason=str(exc),
            ),
        )
        return devices
    mps = getattr(getattr(torch, "backends", None), "mps", None)
    mps_available = bool(mps is not None and mps.is_available())
    cuda_available = bool(getattr(torch, "cuda", None) is not None and torch.cuda.is_available())
    devices.append(DeviceInfo("mps", mps_available, "torch", "" if mps_available else "torch MPS unavailable"))
    devices.append(DeviceInfo("cuda", cuda_available, "torch", "" if cuda_available else "torch CUDA unavailable"))
    for item in devices:
        if not item.available:
            _LOG.debug(
                "device unavailable",
                extra=event_fields(
                    event="device_unavailable",
                    stage="detect_devices",
                    backend=item.backend,
                    device=item.name,
                    status="skipped",
                    reason=item.reason,
                ),
            )
    _LOG.debug(
        "device probe completed",
        extra=event_fields(
            event="device_probe", stage="detect_devices", backend="torch", status="ok", rows=len(devices)
        ),
    )
    return devices


def resolve_torch_device(device: str, allow_cpu_fallback: bool) -> str:
    available = {item.name: item for item in detect_devices()}
    if device not in available:
        raise ValueError(f"unknown device {device!r}")
    if available[device].available:
        return device
    if allow_cpu_fallback:
        _LOG.warning(
            "falling back to CPU device",
            extra=event_fields(
                event="device_fallback",
                stage="resolve_torch_device",
                backend="torch",
                device=device,
                status="degraded",
                reason=available[device].reason,
            ),
        )
        return "cpu"
    raise BackendUnavailable(f"device {device!r} unavailable: {available[device].reason}")


def _torch_geometry(torch, z, request: RunRequest):
    e = torch.exp(-0.5 * (z - 2.5) ** 2)
    g = z - 3.4 + 0.95 * e
    gp = 1.0 - 0.95 * (z - 2.5) * e
    gpp = -0.95 * (1.0 - (z - 2.5) ** 2) * e
    kernel = torch.exp(-50.0 * g**4)
    amplitude = request.rmax * request.severity / 100.0
    r0 = request.rmax - amplitude * kernel
    r0z = 200.0 * amplitude * kernel * g**3 * gp
    r0zz = 200.0 * amplitude * kernel * (3.0 * g**2 * gp**2 + g**3 * gpp - 200.0 * g**6 * gp**2)
    return r0, r0z, r0zz


def _torch_effective_nu(torch, area, flow, z, request: RunRequest):
    r0, _, _ = _torch_geometry(torch, z, request)
    a_safe = torch.clamp(area, min=AREA_FLOOR)
    shear = (
        request.velocity_profile.gamma_plus_two * torch.abs(flow) / a_safe / torch.clamp(r0, min=math.sqrt(AREA_FLOOR))
    )
    gamma = torch.clamp(torch.abs(shear), min=request.rheology.shear_floor)
    if request.rheology.descriptor == "newtonian":
        eta = torch.full_like(area, request.rho * request.nu)
    elif request.rheology.descriptor == "carreau":
        eta = request.rheology.eta_inf + (request.rheology.eta0 - request.rheology.eta_inf) * (
            1.0 + (request.rheology.lambda_s * gamma) ** 2.0
        ) ** ((request.rheology.flow_index - 1.0) / 2.0)
    elif request.rheology.descriptor == "carreau-yasuda":
        eta = request.rheology.eta_inf + (request.rheology.eta0 - request.rheology.eta_inf) * (
            1.0 + (request.rheology.lambda_s * gamma) ** request.rheology.yasuda_a
        ) ** ((request.rheology.flow_index - 1.0) / request.rheology.yasuda_a)
    elif request.rheology.descriptor == "casson":
        eta = (
            torch.sqrt(torch.as_tensor(request.rheology.yield_stress, dtype=area.dtype, device=area.device) / gamma)
            + math.sqrt(request.rheology.plastic_viscosity)
        ) ** 2
    elif request.rheology.descriptor == "power-law":
        eta = request.rheology.consistency * gamma ** (request.rheology.flow_index - 1.0)
    else:
        raise ValueError(f"unknown rheology {request.rheology.descriptor!r}")
    return eta / request.rho


def _torch_wall_reference_radius(request: RunRequest) -> float:
    if request.model.wall_law != "canic-koiter-thin-membrane":
        raise ValueError(f"unsupported wall law {request.model.wall_law!r}")
    return request.rmax


def _torch_wall_elastic_potential(torch, area, z, request: RunRequest):
    _ = torch, z
    a_safe = area.clamp(min=AREA_FLOOR)
    return request.wall_stiffness / (3.0 * request.rho * _torch_wall_reference_radius(request) ** 2) * a_safe**1.5


def _torch_wall_wave_speed_squared(torch, area, z, request: RunRequest):
    _ = z
    a_safe = area.clamp(min=AREA_FLOOR)
    return (
        request.wall_stiffness / (2.0 * request.rho * _torch_wall_reference_radius(request) ** 2) * torch.sqrt(a_safe)
    )


def _torch_wall_geometry_source(torch, area, z, r0z, request: RunRequest):
    _ = torch, z
    a_safe = area.clamp(min=AREA_FLOOR)
    return request.wall_stiffness / (request.rho * _torch_wall_reference_radius(request) ** 2) * a_safe * r0z


def _torch_invariant_speed_factor(request: RunRequest) -> float:
    return math.sqrt(request.wall_stiffness / (2.0 * request.rho * _torch_wall_reference_radius(request) ** 2))


def _torch_flux(torch, area, flow, z, request: RunRequest):
    a_safe = torch.clamp(area, min=AREA_FLOOR)
    _, r0z, _ = _torch_geometry(torch, z, request)
    alpha_c = -2.0 / 35.0 * r0z**2 if request.model.variable_radius_terms else torch.zeros_like(r0z)
    alpha_eff = request.velocity_profile.momentum_alpha + alpha_c
    elastic = _torch_wall_elastic_potential(torch, a_safe, z, request)
    return flow, alpha_eff * flow**2 / a_safe + elastic


def _torch_wave_speed(torch, area, flow, z, request: RunRequest):
    a_safe = torch.clamp(area, min=AREA_FLOOR)
    _, r0z, _ = _torch_geometry(torch, z, request)
    alpha_c = -2.0 / 35.0 * r0z**2 if request.model.variable_radius_terms else torch.zeros_like(r0z)
    alpha_eff = request.velocity_profile.momentum_alpha + alpha_c
    u = flow / a_safe
    elastic = _torch_wall_wave_speed_squared(torch, a_safe, z, request)
    rad = torch.clamp((alpha_eff * u) ** 2 - alpha_eff * u**2 + elastic, min=0.0)
    c = torch.sqrt(rad)
    return torch.maximum(torch.abs(alpha_eff * u - c), torch.abs(alpha_eff * u + c))


def _torch_minmod(torch, left, right):
    same = torch.sign(left) == torch.sign(right)
    return torch.where(
        same, torch.sign(left) * torch.minimum(torch.abs(left), torch.abs(right)), torch.zeros_like(left)
    )


def _torch_slopes(torch, values):
    out = torch.zeros_like(values)
    if values.numel() > 2:
        out[1:-1] = _torch_minmod(torch, values[1:-1] - values[:-2], values[2:] - values[1:-1])
    return out


def _torch_inlet_flow(torch, time: float, request: RunRequest, dtype, device):
    if request.inlet_boundary.descriptor == "flow-waveform":
        waveform = request.inlet_boundary.waveform()
        assert waveform is not None
        times_np, flows_np = waveform
        times = torch.as_tensor(times_np, dtype=dtype, device=device)
        flows = torch.as_tensor(flows_np, dtype=dtype, device=device)
        tau = torch.remainder(torch.as_tensor(time, dtype=dtype, device=device), times[-1])
        idx = torch.clamp(torch.searchsorted(times, tau, right=True) - 1, 0, times.numel() - 2)
        t0 = times[idx]
        t1 = times[idx + 1]
        q0 = flows[idx]
        q1 = flows[idx + 1]
        return q0 + (tau - t0) * (q1 - q0) / (t1 - t0)
    z0 = torch.zeros(1, dtype=dtype, device=device)
    r0, _, _ = _torch_geometry(torch, z0, request)
    return r0[0] ** 2 * request.velocity_profile.mean_to_max_ratio * request.inlet_boundary.umax


def _torch_invariants(torch, area, flow, request: RunRequest):
    a = torch.clamp(area, min=AREA_FLOOR)
    c0 = _torch_invariant_speed_factor(request)
    wplus = flow / a + 4.0 * c0 * a**0.25
    wminus = flow / a - 4.0 * c0 * a**0.25
    return wminus, wplus


def _torch_boundary_states(torch, area, flow, time: float, request: RunRequest, dtype, device):
    z_in = torch.zeros(1, dtype=dtype, device=device)
    r0_in, _, _ = _torch_geometry(torch, z_in, request)
    ain = torch.maximum(
        torch.maximum(area[0], r0_in[0] ** 2),
        torch.as_tensor(AREA_LIMITER_FLOOR, dtype=dtype, device=device),
    )
    qin = _torch_inlet_flow(torch, time, request, dtype, device)
    z_out = torch.as_tensor([request.length_cm], dtype=dtype, device=device)
    r0_out, _, _ = _torch_geometry(torch, z_out, request)
    aref = torch.clamp(r0_out[0] ** 2, min=AREA_LIMITER_FLOOR)
    if request.outlet_boundary.descriptor == "reflection-coefficient":
        qref = torch.as_tensor(request.outlet_boundary.reference_flow, dtype=dtype, device=device)
        _, wplus = _torch_invariants(torch, area[-1], flow[-1], request)
        wminus_ref, wplus_ref = _torch_invariants(torch, aref, qref, request)
        wminus = wminus_ref - request.outlet_boundary.reflection_coefficient * (wplus - wplus_ref)
        c0 = _torch_invariant_speed_factor(request)
        speed_term = torch.clamp((wplus - wminus) / (8.0 * c0), min=AREA_LIMITER_FLOOR**0.25)
        aout = torch.clamp(speed_term**4, min=AREA_LIMITER_FLOOR)
        qout = aout * (0.5 * (wminus + wplus))
    else:
        aout = aref
        qout = flow[-1]
    return ain, qin, aout, qout


def _torch_method_fluxes(torch, area, flow, z, dx: float, time: float, dt: float, request: RunRequest, dtype, device):
    ain, qin, aout, qout = _torch_boundary_states(torch, area, flow, time, request, dtype, device)
    if request.spatial.native_scheme in {"muscl", "lax-wendroff"}:
        slope_a = _torch_slopes(torch, area)
        slope_q = _torch_slopes(torch, flow)
    else:
        slope_a = torch.zeros_like(area)
        slope_q = torch.zeros_like(flow)
    left_a = torch.cat([ain.reshape(1), area[:-1] + 0.5 * slope_a[:-1], area[-1:].reshape(1)])
    left_q = torch.cat([qin.reshape(1), flow[:-1] + 0.5 * slope_q[:-1], flow[-1:].reshape(1)])
    right_a = torch.cat([area[:1].reshape(1), area[1:] - 0.5 * slope_a[1:], aout.reshape(1)])
    right_q = torch.cat([flow[:1].reshape(1), flow[1:] - 0.5 * slope_q[1:], qout.reshape(1)])
    z_faces = torch.cat(
        [
            torch.zeros(1, dtype=dtype, device=device),
            0.5 * (z[:-1] + z[1:]),
            torch.as_tensor([request.length_cm], dtype=dtype, device=device),
        ]
    )
    left_a = torch.clamp(left_a, min=AREA_LIMITER_FLOOR)
    right_a = torch.clamp(right_a, min=AREA_LIMITER_FLOOR)
    fa_l, fq_l = _torch_flux(torch, left_a, left_q, z_faces, request)
    fa_r, fq_r = _torch_flux(torch, right_a, right_q, z_faces, request)
    speed = torch.maximum(
        _torch_wave_speed(torch, left_a, left_q, z_faces, request),
        _torch_wave_speed(torch, right_a, right_q, z_faces, request),
    )
    rusanov_a = 0.5 * (fa_l + fa_r) - 0.5 * speed * (right_a - left_a)
    rusanov_q = 0.5 * (fq_l + fq_r) - 0.5 * speed * (right_q - left_q)
    if request.spatial.native_scheme == "lax-wendroff":
        half_a = 0.5 * (left_a + right_a) - 0.5 * dt / dx * (fa_r - fa_l)
        half_q = 0.5 * (left_q + right_q) - 0.5 * dt / dx * (fq_r - fq_l)
        half_u = half_q / torch.clamp(half_a, min=AREA_LIMITER_FLOOR)
        local_u = torch.maximum(torch.abs(left_q / left_a), torch.abs(right_q / right_a))
        velocity_limit = 2.0 * (local_u + speed + 1.0)
        area_min = torch.minimum(left_a, right_a)
        area_max = torch.maximum(left_a, right_a)
        usable = (
            torch.isfinite(half_a)
            & torch.isfinite(half_q)
            & (half_a > AREA_LIMITER_FLOOR)
            & (half_a >= 0.5 * area_min)
            & (half_a <= 2.0 * area_max)
            & (torch.abs(half_u) <= velocity_limit)
        )
        lw_a, lw_q = _torch_flux(torch, torch.clamp(half_a, min=AREA_LIMITER_FLOOR), half_q, z_faces, request)
        flux_a = torch.where(usable, lw_a, rusanov_a)
        flux_q = torch.where(usable, lw_q, rusanov_q)
        return flux_a, flux_q
    flux_a = rusanov_a
    flux_q = rusanov_q
    return flux_a, flux_q


def _torch_source(torch, area, flow, z, dx: float, request: RunRequest):
    _ = dx
    a_safe = torch.clamp(area, min=AREA_FLOOR)
    _, r0z, _ = _torch_geometry(torch, z, request)
    nu_eff = _torch_effective_nu(torch, a_safe, flow, z, request)
    stiffness_source = _torch_wall_geometry_source(torch, a_safe, z, r0z, request)
    friction = -2.0 * nu_eff * request.velocity_profile.gamma_plus_two * flow / a_safe
    return stiffness_source + friction


def _torch_rhs(torch, area, flow, z, dx: float, time: float, dt: float, request: RunRequest, dtype, device):
    flux_a, flux_q = _torch_method_fluxes(torch, area, flow, z, dx, time, dt, request, dtype, device)
    da = -(flux_a[1:] - flux_a[:-1]) / dx
    dq = -(flux_q[1:] - flux_q[:-1]) / dx + _torch_source(torch, area, flow, z, dx, request)
    return da, dq


def _torch_step(torch, area, flow, z, dx: float, time: float, dt: float, request: RunRequest, dtype, device):
    if request.time_stepper.descriptor == "euler":
        da, dq = _torch_rhs(torch, area, flow, z, dx, time, dt, request, dtype, device)
        return area + dt * da, flow + dt * dq
    if request.time_stepper.descriptor == "ssprk2":
        k1a, k1q = _torch_rhs(torch, area, flow, z, dx, time, dt, request, dtype, device)
        a1, q1 = area + dt * k1a, flow + dt * k1q
        k2a, k2q = _torch_rhs(torch, a1, q1, z, dx, time + dt, dt, request, dtype, device)
        return 0.5 * area + 0.5 * (a1 + dt * k2a), 0.5 * flow + 0.5 * (q1 + dt * k2q)
    k1a, k1q = _torch_rhs(torch, area, flow, z, dx, time, dt, request, dtype, device)
    a1, q1 = area + dt * k1a, flow + dt * k1q
    k2a, k2q = _torch_rhs(torch, a1, q1, z, dx, time + dt, dt, request, dtype, device)
    a2, q2 = 0.75 * area + 0.25 * (a1 + dt * k2a), 0.75 * flow + 0.25 * (q1 + dt * k2q)
    k3a, k3q = _torch_rhs(torch, a2, q2, z, dx, time + 0.5 * dt, dt, request, dtype, device)
    return (area + 2.0 * (a2 + dt * k3a)) / 3.0, (flow + 2.0 * (q2 + dt * k3q)) / 3.0


def run_torch(
    request: RunRequest, device: str = "cpu", allow_cpu_fallback: bool = False
) -> tuple[SimulationResult, str]:
    started = perf_counter()
    if request.spatial.family == "fem":
        raise BackendUnavailable("fem-stationary-stokes is a CPU native projection path")
    selected = resolve_torch_device(device, allow_cpu_fallback)
    try:
        import torch  # type: ignore[import-not-found]
    except Exception as exc:
        raise BackendUnavailable(f"torch unavailable: {exc}") from exc
    torch_device = torch.device(selected)
    dtype_name = resolve_dtype_name(request, "torch", selected)
    if selected == "mps" and dtype_name == "float64":
        raise BackendUnavailable("Torch MPS float64 is not supported; use --dtype auto or --dtype float32")
    dtype = torch.float32 if dtype_name == "float32" else torch.float64
    z_np, dx = grid(request)
    times = save_times(request)
    area_np, flow_np = initial_state(z_np, request)
    z = torch.as_tensor(z_np, dtype=dtype, device=torch_device)
    area = torch.as_tensor(area_np, dtype=dtype, device=torch_device)
    flow = torch.as_tensor(flow_np, dtype=dtype, device=torch_device)
    area_hist = np.empty((request.nx, times.size))
    flow_hist = np.empty((request.nx, times.size))
    area_hist[:, 0] = area_np
    flow_hist[:, 0] = flow_np
    t = 0.0
    steps = 0
    dts: list[float] = []

    for out_idx in range(1, times.size):
        target = float(times[out_idx])
        while t < target - 10.0 * np.finfo(float).eps:
            speed = torch.max(_torch_wave_speed(torch, area, flow, z, request))
            dt = min(target - t, request.dt, request.cfl * dx / max(float(speed.detach().cpu()), 1.0e-12))
            area, flow = _torch_step(torch, area, flow, z, dx, t, dt, request, dtype, torch_device)
            area = torch.clamp(area, min=AREA_LIMITER_FLOOR)
            if not bool(torch.isfinite(area).all()) or not bool(torch.isfinite(flow).all()):
                raise FloatingPointError("nonfinite state")
            t += dt
            steps += 1
            dts.append(float(dt))
        area_hist[:, out_idx] = area.detach().cpu().numpy().astype(float)
        flow_hist[:, out_idx] = flow.detach().cpu().numpy().astype(float)
    elapsed_s = round(perf_counter() - started, 6)
    result = SimulationResult(
        z_np,
        times,
        area_hist,
        flow_hist,
        pressure(area_hist, flow_hist, z_np, request),
        steps,
        {
            "mode": "torch-tensor-update",
            "rhs": "torch-native",
            "dtype": dtype_name,
            "runtime_seconds": elapsed_s,
            **dt_stats(dts),
        },
    )
    return result, selected


def run_scipy(request: RunRequest) -> SimulationResult:
    started = perf_counter()
    if request.spatial.family == "fem":
        raise BackendUnavailable("SciPy adapter is for time-dependent FV/DG smoke runs")
    try:
        from scipy.integrate import solve_ivp  # type: ignore[import-not-found]
    except Exception as exc:
        raise BackendUnavailable("SciPy backend requires scipy; install scipy or use --backend native") from exc
    z, dx = grid(request)
    times = save_times(request)
    area0, flow0 = initial_state(z, request)
    state0 = np.concatenate([area0, flow0])

    def flat_rhs(time: float, state: np.ndarray) -> np.ndarray:
        a = state[: request.nx]
        q = state[request.nx :]
        da, dq = rhs(a, q, z, dx, time, request.dt, request)
        return np.concatenate([da, dq])

    solution = solve_ivp(
        flat_rhs, (0.0, request.tfinal), state0, method=request.scipy_method, t_eval=times, rtol=1.0e-5, atol=1.0e-8
    )
    if not solution.success:
        raise FloatingPointError(solution.message)
    area = np.maximum(solution.y[: request.nx, :], 1.0e-10)
    flow = solution.y[request.nx :, :]
    elapsed_s = round(perf_counter() - started, 6)
    return SimulationResult(
        z,
        times,
        area,
        flow,
        pressure(area, flow, z, request),
        int(solution.nfev),
        {"mode": "scipy-solve-ivp", "dtype": "float64", "runtime_seconds": elapsed_s, **dt_stats([])},
    )


def run_sciml_reference(request: RunRequest) -> SimulationResult:
    if request.julia_project is None:
        raise BackendUnavailable("sciml-reference requires --julia-project /Users/doe/hemodynamics/masters-report")
    project = request.julia_project.expanduser().resolve()
    script = project / "simulations" / "run_canic_extended_1d.jl"
    runner = project / "scripts" / "julia-release"
    if not script.exists():
        raise BackendUnavailable(f"Julia simulation script not found: {script}")
    command_prefix = [str(runner)] if runner.exists() else ["julia", "--project", str(project)]
    if not Path(command_prefix[0]).exists() and shutil.which(command_prefix[0]) is None:
        raise BackendUnavailable(f"Julia runner unavailable: {command_prefix[0]}")
    with tempfile.TemporaryDirectory(prefix="research-hemodynamics-sciml-") as tmp:
        csv_path = Path(tmp) / "result.csv"
        space_args = ["--space", request.spatial.descriptor]
        if request.spatial.family == "dg":
            space_args = ["--space", "dg", "--degree", str(request.spatial.degree or 0)]
        command = [
            *command_prefix,
            str(script),
            "--nx",
            str(request.nx),
            "--tfinal",
            str(request.tfinal),
            "--dt",
            str(request.dt),
            "--severity",
            str(request.severity),
            *space_args,
            "--time-stepper",
            request.time_stepper.descriptor,
            "--ic",
            "geometry-rest",
            "--backend",
            "sciml",
            "--alg",
            request.sciml_label,
            "--output",
            str(csv_path),
            "--no-svg",
            "--progress-every",
            "0",
        ]
        started = perf_counter()
        _LOG.debug(
            "SciML subprocess starting",
            extra=event_fields(
                event="subprocess_started",
                stage="sciml_reference",
                backend="sciml-reference",
                method=request.spatial.descriptor,
                nx=request.nx,
                tfinal=request.tfinal,
                status="started",
                command=" ".join(command),
            ),
        )
        completed = subprocess.run(command, cwd=project, text=True, capture_output=True, timeout=60, check=False)
        elapsed_s = round(perf_counter() - started, 6)
        if completed.returncode != 0:
            _LOG.warning(
                "SciML subprocess failed",
                extra=event_fields(
                    event="subprocess_failed",
                    stage="sciml_reference",
                    backend="sciml-reference",
                    method=request.spatial.descriptor,
                    nx=request.nx,
                    tfinal=request.tfinal,
                    status="error",
                    elapsed_s=elapsed_s,
                    reason=completed.stderr.strip() or completed.stdout.strip() or f"returncode={completed.returncode}",
                ),
            )
            raise BackendUnavailable(completed.stderr.strip() or completed.stdout.strip())
        rows = list(csv.DictReader(csv_path.read_text().splitlines()))
        _LOG.info(
            "SciML subprocess completed",
            extra=event_fields(
                event="subprocess_completed",
                stage="sciml_reference",
                backend="sciml-reference",
                method=request.spatial.descriptor,
                nx=request.nx,
                tfinal=request.tfinal,
                status="ok",
                elapsed_s=elapsed_s,
                rows=len(rows),
            ),
        )
        z = np.asarray([float(row["z_cm"]) for row in rows])
        area_last = np.asarray([float(row["A_cm2"]) for row in rows])
        flow_last = np.asarray([float(row["Q_cm3_s"]) for row in rows])
        times = save_times(request)
        area = np.repeat(area_last[:, None], times.size, axis=1)
        flow = np.repeat(flow_last[:, None], times.size, axis=1)
        return SimulationResult(
            z,
            times,
            area,
            flow,
            pressure(area, flow, z, request),
            0,
            {"mode": "sciml-reference", "dtype": "float64", "runtime_seconds": elapsed_s, **dt_stats([])},
        )


def run_backend(
    request: RunRequest, backend: str, *, device: str = "cpu", allow_cpu_fallback: bool = False
) -> tuple[SimulationResult, str]:
    normalized = backend.strip().lower().replace("_", "-")
    started = perf_counter()
    _LOG.info(
        "backend started",
        extra=event_fields(
            event="backend_started",
            stage="run_backend",
            backend=normalized,
            device=device,
            method=request.spatial.descriptor,
            nx=request.nx,
            tfinal=request.tfinal,
            status="started",
        ),
    )
    try:
        if normalized in {"native", "numpy"}:
            result, selected = run_native(request), "cpu"
        elif normalized == "torch":
            result, selected = run_torch(request, device=device, allow_cpu_fallback=allow_cpu_fallback)
        elif normalized == "scipy":
            result, selected = run_scipy(request), "cpu"
        elif normalized in {"sciml", "sciml-reference"}:
            result, selected = run_sciml_reference(request), "cpu"
        else:
            raise ValueError("unknown backend {!r}; expected native, torch, scipy, or sciml-reference".format(backend))
    except Exception as exc:
        _LOG.exception(
            "backend failed",
            extra=event_fields(
                event="backend_failed",
                stage="run_backend",
                backend=normalized,
                device=device,
                method=request.spatial.descriptor,
                nx=request.nx,
                tfinal=request.tfinal,
                status="error",
                elapsed_s=round(perf_counter() - started, 6),
                reason=str(exc),
            ),
        )
        raise
    _LOG.info(
        "backend completed",
        extra=event_fields(
            event="backend_completed",
            stage="run_backend",
            backend=normalized,
            device=selected,
            method=request.spatial.descriptor,
            nx=request.nx,
            tfinal=request.tfinal,
            status="ok",
            elapsed_s=round(perf_counter() - started, 6),
            rows=result.area.shape[0],
        ),
    )
    return result, selected


def compare_backends(
    request: RunRequest,
    left_backend: str,
    right_backend: str,
    *,
    device: str = "cpu",
    allow_cpu_fallback: bool = False,
) -> dict[str, Any]:
    left, left_device = run_backend(
        request,
        left_backend,
        device=device if left_backend.strip().lower().replace("_", "-") == "torch" else "cpu",
        allow_cpu_fallback=allow_cpu_fallback,
    )
    right, right_device = run_backend(
        request,
        right_backend,
        device=device if right_backend.strip().lower().replace("_", "-") == "torch" else "cpu",
        allow_cpu_fallback=allow_cpu_fallback,
    )
    payload = compare_metrics(left, right)
    payload["left_backend"] = left_backend
    payload["right_backend"] = right_backend
    payload["left_device"] = left_device
    payload["right_device"] = right_device
    return payload
