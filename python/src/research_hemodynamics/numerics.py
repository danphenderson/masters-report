"""Lightweight 1D hemodynamics numerics for the Python CLI."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter
from typing import Any

import numpy as np

from .logging import event_fields, get_logger
from .strategies import (
    InletBoundaryStrategy,
    OutletBoundaryStrategy,
    RheologyStrategy,
    SpatialStrategy,
    TimeStepperStrategy,
    VelocityProfileStrategy,
)

AREA_FLOOR = 1.0e-12
AREA_LIMITER_FLOOR = 1.0e-10
_LOG = get_logger(__name__)


@dataclass(frozen=True)
class RunRequest:
    spatial: SpatialStrategy
    time_stepper: TimeStepperStrategy
    rheology: RheologyStrategy
    velocity_profile: VelocityProfileStrategy
    inlet_boundary: InletBoundaryStrategy
    outlet_boundary: OutletBoundaryStrategy
    initial_condition: str = "geometry-rest"
    nx: int = 64
    length_cm: float = 6.0
    tfinal: float = 0.02
    dt: float = 1.0e-4
    cfl: float = 0.35
    saveat: float = 0.01
    severity: float = 50.0
    rmax: float = 0.18
    rho: float = 1.055
    nu: float = 0.04
    young: float = 5.02e6
    wall_h: float = 0.06
    sigma: float = 0.5
    ic_pressure_drop_dyn_cm2: float = 1000.0
    ic_mesh_nz: int = 64
    scipy_method: str = "RK45"
    sciml_label: str = "auto"
    julia_project: Path | None = None

    @property
    def wall_stiffness(self) -> float:
        return self.young * self.wall_h / (1.0 - self.sigma**2)


@dataclass(frozen=True)
class SimulationResult:
    z: np.ndarray
    t: np.ndarray
    area: np.ndarray
    flow: np.ndarray
    pressure: np.ndarray
    steps: int
    metadata: dict[str, Any]

    def summary(self) -> dict[str, Any]:
        velocity = self.flow / np.maximum(self.area, AREA_FLOOR)
        return {
            "steps": self.steps,
            "completed_time": float(self.t[-1]),
            "area_min": float(np.min(self.area)),
            "area_mean_final": float(np.mean(self.area[:, -1])),
            "flow_mean_final": float(np.mean(self.flow[:, -1])),
            "pressure_mean_final": float(np.mean(self.pressure[:, -1])),
            "velocity_max": float(np.max(np.abs(velocity))),
        }


def asymmetric_geometry_terms(z: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    e = np.exp(-0.5 * (z - 2.5) ** 2)
    g = z - 3.4 + 0.95 * e
    gp = 1.0 - 0.95 * (z - 2.5) * e
    gpp = -0.95 * (1.0 - (z - 2.5) ** 2) * e
    kernel = np.exp(-50.0 * g**4)
    return g, gp, gpp, kernel


def stenosis(z: np.ndarray | float, request: RunRequest) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    z_arr = np.asarray(z, dtype=float)
    amplitude = request.rmax * request.severity / 100.0
    g, gp, gpp, kernel = asymmetric_geometry_terms(z_arr)
    r0 = request.rmax - amplitude * kernel
    r0z = 200.0 * amplitude * kernel * g**3 * gp
    r0zz = 200.0 * amplitude * kernel * (3.0 * g**2 * gp**2 + g**3 * gpp - 200.0 * g**6 * gp**2)
    return r0, r0z, r0zz


def grid(request: RunRequest) -> tuple[np.ndarray, float]:
    if request.nx < 8:
        raise ValueError("--nx must be at least 8")
    dx = request.length_cm / request.nx
    return np.linspace(0.5 * dx, request.length_cm - 0.5 * dx, request.nx), dx


def pressure(area: np.ndarray, flow: np.ndarray, z: np.ndarray, request: RunRequest) -> np.ndarray:
    r0, r0z, _ = stenosis(z[:, None] if area.ndim == 2 else z, request)
    r0_safe = np.maximum(r0, math.sqrt(AREA_LIMITER_FLOOR))
    a_safe = np.maximum(area, AREA_FLOOR)
    radius = np.sqrt(a_safe)
    elastic = request.wall_stiffness / (r0_safe**2) * (radius - r0_safe)
    viscous = request.velocity_profile.gamma_plus_two * request.rho * request.nu * flow / a_safe * (r0z / r0_safe)
    return elastic + viscous


def characteristic_shear_rate(area: np.ndarray, flow: np.ndarray, r0: np.ndarray, request: RunRequest) -> np.ndarray:
    a_safe = np.maximum(area, AREA_FLOOR)
    return request.velocity_profile.gamma_plus_two * np.abs(flow) / a_safe / np.maximum(r0, math.sqrt(AREA_FLOOR))


def effective_nu(area: np.ndarray, flow: np.ndarray, z: np.ndarray, request: RunRequest) -> np.ndarray:
    r0, _, _ = stenosis(z, request)
    shear = characteristic_shear_rate(area, flow, r0, request)
    eta = np.vectorize(lambda gamma: request.rheology.dynamic_viscosity(float(gamma), request.nu, request.rho))(shear)
    return eta / request.rho


def flux(area: np.ndarray, flow: np.ndarray, z: np.ndarray, request: RunRequest) -> tuple[np.ndarray, np.ndarray]:
    a_safe = np.maximum(area, AREA_FLOOR)
    _, r0z, _ = stenosis(z, request)
    alpha_eff = request.velocity_profile.momentum_alpha - 2.0 / 35.0 * r0z**2
    elastic = request.wall_stiffness / (3.0 * request.rho * request.rmax**2) * a_safe**1.5
    return flow, alpha_eff * flow**2 / a_safe + elastic


def max_wave_speed(area: np.ndarray, flow: np.ndarray, z: np.ndarray, request: RunRequest) -> np.ndarray:
    a_safe = np.maximum(area, AREA_FLOOR)
    _, r0z, _ = stenosis(z, request)
    alpha_eff = request.velocity_profile.momentum_alpha - 2.0 / 35.0 * r0z**2
    u = flow / a_safe
    elastic = request.wall_stiffness / (2.0 * request.rho * request.rmax**2) * np.sqrt(a_safe)
    rad = np.maximum((alpha_eff * u) ** 2 - alpha_eff * u**2 + elastic, 0.0)
    c = np.sqrt(rad)
    return np.maximum(np.abs(alpha_eff * u - c), np.abs(alpha_eff * u + c))


def minmod(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    same = np.sign(a) == np.sign(b)
    return np.where(same, np.sign(a) * np.minimum(np.abs(a), np.abs(b)), 0.0)


def slopes(values: np.ndarray) -> np.ndarray:
    out = np.zeros_like(values)
    out[1:-1] = minmod(values[1:-1] - values[:-2], values[2:] - values[1:-1])
    return out


def inlet_flow(t: float, request: RunRequest) -> float:
    if request.inlet_boundary.descriptor == "flow-waveform":
        waveform = request.inlet_boundary.waveform()
        assert waveform is not None
        times, flows = waveform
        tau = t % float(times[-1])
        return float(np.interp(tau, times, flows))
    r0, _, _ = stenosis(np.asarray([0.0]), request)
    return float(r0[0] ** 2 * request.velocity_profile.mean_to_max_ratio * request.inlet_boundary.umax)


def invariant_speed_factor(request: RunRequest) -> float:
    return math.sqrt(request.wall_stiffness / (2.0 * request.rho * request.rmax**2))


def invariant_plus(area: float, flow: float, request: RunRequest) -> float:
    a = max(area, AREA_FLOOR)
    return flow / a + 4.0 * invariant_speed_factor(request) * a**0.25


def invariant_minus(area: float, flow: float, request: RunRequest) -> float:
    a = max(area, AREA_FLOOR)
    return flow / a - 4.0 * invariant_speed_factor(request) * a**0.25


def state_from_invariants(wminus: float, wplus: float, request: RunRequest) -> tuple[float, float]:
    c0 = invariant_speed_factor(request)
    speed_term = max((wplus - wminus) / (8.0 * c0), AREA_LIMITER_FLOOR**0.25)
    area = max(speed_term**4, AREA_LIMITER_FLOOR)
    u = 0.5 * (wminus + wplus)
    return area, area * u


def boundary_states(
    area: np.ndarray, flow: np.ndarray, request: RunRequest, t: float
) -> tuple[float, float, float, float]:
    r0_in, _, _ = stenosis(np.asarray([0.0]), request)
    ain = max(float(area[0]), float(r0_in[0] ** 2), AREA_LIMITER_FLOOR)
    qin = inlet_flow(t, request)
    r0_out, _, _ = stenosis(np.asarray([request.length_cm]), request)
    aref = max(float(r0_out[0] ** 2), AREA_LIMITER_FLOOR)
    if request.outlet_boundary.descriptor == "reflection-coefficient":
        qref = request.outlet_boundary.reference_flow
        wplus = invariant_plus(float(area[-1]), float(flow[-1]), request)
        wminus_ref = invariant_minus(aref, qref, request)
        wplus_ref = invariant_plus(aref, qref, request)
        wminus = wminus_ref - request.outlet_boundary.reflection_coefficient * (wplus - wplus_ref)
        aout, qout = state_from_invariants(wminus, wplus, request)
    else:
        aout = aref
        qout = float(flow[-1])
    return ain, qin, aout, qout


def rusanov_flux(al: float, ql: float, ar: float, qr: float, z: float, request: RunRequest) -> tuple[float, float]:
    zl = np.asarray([z])
    fa_l, fq_l = flux(np.asarray([al]), np.asarray([ql]), zl, request)
    fa_r, fq_r = flux(np.asarray([ar]), np.asarray([qr]), zl, request)
    speed = max(
        float(max_wave_speed(np.asarray([al]), np.asarray([ql]), zl, request)[0]),
        float(max_wave_speed(np.asarray([ar]), np.asarray([qr]), zl, request)[0]),
    )
    return (
        0.5 * (fa_l[0] + fa_r[0]) - 0.5 * speed * (ar - al),
        0.5 * (fq_l[0] + fq_r[0]) - 0.5 * speed * (qr - ql),
    )


def lax_wendroff_interface_state(
    al: float,
    ql: float,
    ar: float,
    qr: float,
    z: float,
    dx: float,
    dt: float,
    request: RunRequest,
) -> tuple[float, float, bool]:
    """Return the Richtmyer half-step interface state and whether it is usable."""

    if dx <= 0.0:
        raise ValueError("Lax-Wendroff requires positive dx")
    if dt <= 0.0:
        raise ValueError("Lax-Wendroff requires positive dt")
    left_a = max(float(al), AREA_LIMITER_FLOOR)
    right_a = max(float(ar), AREA_LIMITER_FLOOR)
    zl = np.asarray([z])
    fa_l, fq_l = flux(np.asarray([left_a]), np.asarray([ql]), zl, request)
    fa_r, fq_r = flux(np.asarray([right_a]), np.asarray([qr]), zl, request)
    ah = 0.5 * (left_a + right_a) - 0.5 * dt / dx * float(fa_r[0] - fa_l[0])
    qh = 0.5 * (float(ql) + float(qr)) - 0.5 * dt / dx * float(fq_r[0] - fq_l[0])
    speed = max(
        float(max_wave_speed(np.asarray([left_a]), np.asarray([ql]), zl, request)[0]),
        float(max_wave_speed(np.asarray([right_a]), np.asarray([qr]), zl, request)[0]),
    )
    half_u = qh / max(ah, AREA_LIMITER_FLOOR) if math.isfinite(ah) else math.inf
    velocity_limit = 2.0 * (max(abs(float(ql) / left_a), abs(float(qr) / right_a)) + speed + 1.0)
    usable = (
        math.isfinite(ah)
        and math.isfinite(qh)
        and ah > AREA_LIMITER_FLOOR
        and ah >= 0.5 * min(left_a, right_a)
        and ah <= 2.0 * max(left_a, right_a)
        and abs(half_u) <= velocity_limit
    )
    return max(ah, AREA_LIMITER_FLOOR), qh, usable


def lax_wendroff_flux(
    al: float,
    ql: float,
    ar: float,
    qr: float,
    z: float,
    dx: float,
    dt: float,
    request: RunRequest,
) -> tuple[float, float]:
    ah, qh, usable = lax_wendroff_interface_state(al, ql, ar, qr, z, dx, dt, request)
    left_a = max(al, AREA_LIMITER_FLOOR)
    right_a = max(ar, AREA_LIMITER_FLOOR)
    if not usable:
        return rusanov_flux(left_a, ql, right_a, qr, z, request)
    fa, fq = flux(np.asarray([ah]), np.asarray([qh]), np.asarray([z]), request)
    return float(fa[0]), float(fq[0])


def method_fluxes(
    area: np.ndarray, flow: np.ndarray, z: np.ndarray, dx: float, t: float, dt: float, request: RunRequest
) -> ArrayPair:
    nx = area.size
    fa = np.empty(nx + 1)
    fq = np.empty(nx + 1)
    ain, qin, aout, qout = boundary_states(area, flow, request, t)
    reconstructed = request.spatial.native_scheme in {"muscl", "lax-wendroff"}
    slope_a = slopes(area) if reconstructed else np.zeros_like(area)
    slope_q = slopes(flow) if reconstructed else np.zeros_like(flow)
    for iface in range(nx + 1):
        if iface == 0:
            al, ql, ar, qr, zi = (
                ain,
                qin,
                float(area[0] - 0.5 * slope_a[0]),
                float(flow[0] - 0.5 * slope_q[0]),
                0.0,
            )
        elif iface == nx:
            al, ql, ar, qr, zi = (
                float(area[-1] + 0.5 * slope_a[-1]),
                float(flow[-1] + 0.5 * slope_q[-1]),
                aout,
                qout,
                request.length_cm,
            )
        else:
            al = float(area[iface - 1] + 0.5 * slope_a[iface - 1])
            ql = float(flow[iface - 1] + 0.5 * slope_q[iface - 1])
            ar = float(area[iface] - 0.5 * slope_a[iface])
            qr = float(flow[iface] - 0.5 * slope_q[iface])
            zi = 0.5 * (z[iface - 1] + z[iface])
        left_a = max(al, AREA_LIMITER_FLOOR)
        right_a = max(ar, AREA_LIMITER_FLOOR)
        if request.spatial.native_scheme == "lax-wendroff":
            fa[iface], fq[iface] = lax_wendroff_flux(left_a, ql, right_a, qr, zi, dx, dt, request)
        else:
            fa[iface], fq[iface] = rusanov_flux(left_a, ql, right_a, qr, zi, request)
    return fa, fq


def source(area: np.ndarray, flow: np.ndarray, z: np.ndarray, dx: float, request: RunRequest) -> np.ndarray:
    a_safe = np.maximum(area, AREA_FLOOR)
    r0, r0z, _ = stenosis(z, request)
    nu_eff = effective_nu(a_safe, flow, z, request)
    stiffness_source = request.wall_stiffness / (request.rho * request.rmax**2) * a_safe * r0z
    friction = -2.0 * nu_eff * request.velocity_profile.gamma_plus_two * flow / a_safe
    return stiffness_source + friction


def rhs(
    area: np.ndarray, flow: np.ndarray, z: np.ndarray, dx: float, t: float, dt: float, request: RunRequest
) -> ArrayPair:
    fa, fq = method_fluxes(area, flow, z, dx, t, dt, request)
    da = -(fa[1:] - fa[:-1]) / dx
    dq = -(fq[1:] - fq[:-1]) / dx + source(area, flow, z, dx, request)
    return da, dq


def geometry_rest_state(z: np.ndarray, request: RunRequest) -> ArrayPair:
    r0, _, _ = stenosis(z, request)
    return np.maximum(r0**2, AREA_LIMITER_FLOOR), np.zeros_like(z)


def stationary_stokes_state(z: np.ndarray, request: RunRequest) -> ArrayPair:
    samples = max(10 * request.ic_mesh_nz, 200)
    zq = np.linspace(0.0, request.length_cm, samples + 1)
    r0q, _, _ = stenosis(zq, request)
    weights = np.ones_like(zq)
    weights[0] = weights[-1] = 0.5
    resistance = float(
        np.sum(weights / np.maximum(r0q, math.sqrt(AREA_LIMITER_FLOOR)) ** 4) * (request.length_cm / samples)
    )
    flow_over_area_factor = request.ic_pressure_drop_dyn_cm2 / (8.0 * request.rho * request.nu * resistance)
    area = np.empty_like(z)
    flow = np.empty_like(z)
    for i, zi in enumerate(z):
        r0, _, _ = stenosis(np.asarray([zi]), request)
        radius = float(r0[0])
        uavg = flow_over_area_factor / radius**2
        local_z = np.linspace(float(zi), request.length_cm, samples + 1)
        local_r0, _, _ = stenosis(local_z, request)
        pressure_i = request.ic_pressure_drop_dyn_cm2 * float(np.trapezoid(1.0 / local_r0**4, local_z)) / resistance
        area_i = max((radius + pressure_i * radius**2 / request.wall_stiffness) ** 2, AREA_LIMITER_FLOOR)
        area[i] = area_i
        flow[i] = area_i * uavg
    return area, flow


def initial_state(z: np.ndarray, request: RunRequest) -> ArrayPair:
    if request.spatial.descriptor == "fem-stationary-stokes" or request.initial_condition == "stationary-stokes":
        return stationary_stokes_state(z, request)
    return geometry_rest_state(z, request)


def save_times(request: RunRequest) -> np.ndarray:
    times = [0.0]
    t = 0.0
    while t + request.saveat < request.tfinal - 10.0 * np.finfo(float).eps:
        t += request.saveat
        times.append(t)
    if times[-1] < request.tfinal:
        times.append(request.tfinal)
    return np.asarray(times, dtype=float)


def run_native(request: RunRequest) -> SimulationResult:
    started = perf_counter()
    status_fields = dict(
        stage="run_native",
        backend="native",
        method=request.spatial.descriptor,
        nx=request.nx,
        tfinal=request.tfinal,
    )
    try:
        z, dx = grid(request)
        times = save_times(request)
        area, flow = initial_state(z, request)
        area_hist = np.empty((request.nx, times.size))
        flow_hist = np.empty((request.nx, times.size))
        area_hist[:, 0] = area
        flow_hist[:, 0] = flow
        if request.spatial.family == "fem":
            projection_hash = hashlib.sha256(
                np.ascontiguousarray(np.vstack([z, area, flow]), dtype=np.float64).tobytes()
            ).hexdigest()
            for idx in range(1, times.size):
                area_hist[:, idx] = area
                flow_hist[:, idx] = flow
            result = SimulationResult(
                z,
                times,
                area_hist,
                flow_hist,
                pressure(area_hist, flow_hist, z, request),
                0,
                {"mode": "stationary-stokes-projection", "projection_hash": projection_hash},
            )
            _LOG.info(
                "native solver completed",
                extra=event_fields(
                    event="native_completed",
                    **status_fields,
                    status="ok",
                    elapsed_s=round(perf_counter() - started, 6),
                    rows=result.area.shape[0],
                ),
            )
            return result

        steps = 0
        t = 0.0

        def rhs_for_step(a: np.ndarray, q: np.ndarray, time: float, step_dt: float) -> ArrayPair:
            return rhs(a, q, z, dx, time, step_dt, request)

        for out_idx in range(1, times.size):
            target = float(times[out_idx])
            while t < target - 10.0 * np.finfo(float).eps:
                speed = float(np.max(max_wave_speed(area, flow, z, request)))
                dt = min(target - t, request.dt, request.cfl * dx / max(speed, 1.0e-12))
                area, flow = request.time_stepper.step(area, flow, dt, t, rhs_for_step)
                area = np.maximum(area, AREA_LIMITER_FLOOR)
                if not np.isfinite(area).all() or not np.isfinite(flow).all():
                    raise FloatingPointError("nonfinite state")
                t += dt
                steps += 1
            area_hist[:, out_idx] = area
            flow_hist[:, out_idx] = flow
        result = SimulationResult(
            z,
            times,
            area_hist,
            flow_hist,
            pressure(area_hist, flow_hist, z, request),
            steps,
            {"mode": "finite-volume"},
        )
        _LOG.info(
            "native solver completed",
            extra=event_fields(
                event="native_completed",
                **status_fields,
                status="ok",
                elapsed_s=round(perf_counter() - started, 6),
                rows=result.area.shape[0],
            ),
        )
        return result
    except Exception as exc:
        _LOG.exception(
            "native solver failed",
            extra=event_fields(
                event="native_failed",
                **status_fields,
                status="error",
                elapsed_s=round(perf_counter() - started, 6),
                reason=str(exc),
            ),
        )
        raise


def write_outputs(
    result: SimulationResult, request: RunRequest, out: Path, backend: str, device: str = "cpu"
) -> dict[str, str]:
    started = perf_counter()
    status_fields = dict(
        stage="write_outputs",
        backend=backend,
        device=device,
        method=request.spatial.descriptor,
        nx=request.nx,
        tfinal=request.tfinal,
        output_dir=str(out),
    )
    try:
        out.mkdir(parents=True, exist_ok=True)
        summary_path = out / "summary.json"
        series_path = out / "series.csv"
        npz_path = out / "solution.npz"
        payload = {
            "summary": result.summary(),
            "backend": backend,
            "device": device,
            "metadata": {
                **result.metadata,
                "spatial": request.spatial.metadata(),
                "time_stepper": request.time_stepper.descriptor,
                "rheology": request.rheology.metadata(),
                "velocity_profile": request.velocity_profile.metadata(),
                "initial_condition": request.initial_condition,
                "inlet_boundary": request.inlet_boundary.metadata(),
                "outlet_boundary": request.outlet_boundary.metadata(),
            },
        }
        summary_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        with series_path.open("w", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["t_s", "z_cm", "A_cm2", "Q_cm3_s", "pressure_dyn_cm2"])
            for j, t in enumerate(result.t):
                for i, z_i in enumerate(result.z):
                    writer.writerow([t, z_i, result.area[i, j], result.flow[i, j], result.pressure[i, j]])
        np.savez_compressed(npz_path, t_s=result.t, z_cm=result.z, area_cm2=result.area, flow_cm3_s=result.flow)
        outputs = {"summary_json": str(summary_path), "series_csv": str(series_path), "solution_npz": str(npz_path)}
        _LOG.info(
            "outputs written",
            extra=event_fields(
                event="outputs_written",
                **status_fields,
                status="ok",
                elapsed_s=round(perf_counter() - started, 6),
                rows=int(result.z.size * result.t.size),
            ),
        )
        return outputs
    except Exception as exc:
        _LOG.exception(
            "outputs failed",
            extra=event_fields(
                event="outputs_failed",
                **status_fields,
                status="error",
                elapsed_s=round(perf_counter() - started, 6),
                reason=str(exc),
            ),
        )
        raise


def compare_metrics(left: SimulationResult, right: SimulationResult) -> dict[str, Any]:
    lm = left.summary()
    rm = right.summary()
    keys = ["area_mean_final", "flow_mean_final", "pressure_mean_final", "velocity_max"]
    diff = {key: rm[key] - lm[key] for key in keys}
    rel = {key: abs(diff[key]) / max(abs(lm[key]), np.finfo(float).tiny) for key in keys}
    return {"left": lm, "right": rm, "difference": diff, "relative_difference": rel}
