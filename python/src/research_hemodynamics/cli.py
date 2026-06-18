"""Typer CLI for the self-contained Python hemodynamics package."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

import typer

from .backends import BackendUnavailable, compare_backends, detect_devices, run_backend
from .descriptors import DescriptorFactory, registry
from .experiments import run_backend_parity_experiment
from .logging import configure_logging
from .numerics import RunRequest, load_manifest, validate_dtype_name, write_outputs

app = typer.Typer(
    name="research-hemodynamics", help="Python CLI for CanicExtended1D hemodynamics descriptors.", no_args_is_help=True
)


def emit_json(payload: object) -> None:
    typer.echo(json.dumps(payload, indent=2, sort_keys=True))


def parse_sample_times(value: Optional[str]) -> tuple[float, ...] | None:
    if value is None or not value.strip():
        return None
    try:
        return tuple(float(item.strip()) for item in value.split(",") if item.strip())
    except ValueError as exc:
        raise typer.BadParameter("--sample-times must be a comma-separated list of numbers") from exc


def build_request(
    *,
    model: str,
    space: str,
    time_stepper: str,
    rheology: str,
    velocity_profile: str,
    profile_exponent: Optional[float],
    alpha: Optional[float],
    profile_shear_factor: float,
    inlet: str,
    inlet_umax: float,
    flow_waveform: Optional[Path],
    outlet: str,
    reflection_coefficient: float,
    reference_flow: float,
    ic: str,
    nx: int,
    tfinal: float,
    dt: float,
    cfl: float,
    saveat: float,
    sample_times: tuple[float, ...] | None,
    severity: float,
    ic_pressure_drop_pa: float,
    scipy_method: str,
    sciml_label: str,
    julia_project: Optional[Path],
    dtype: str,
) -> RunRequest:
    factory = DescriptorFactory(registry)
    registry.require("initial-condition", ic)
    registry.require("scipy-method", scipy_method)
    registry.require("sciml-label", sciml_label)
    model_strategy = factory.forward_model(model)
    velocity_strategy = factory.velocity_profile(
        "power" if alpha is not None else velocity_profile,
        exponent=profile_exponent,
        alpha=alpha,
        shear_rate_factor=profile_shear_factor,
    )
    if model_strategy.requires_parabolic_profile and velocity_strategy.descriptor != "parabolic":
        raise ValueError("--model classical-1d-no-slip requires --velocity-profile parabolic and no --alpha override")
    return RunRequest(
        model=model_strategy,
        spatial=factory.spatial(space),
        time_stepper=factory.time_stepper(time_stepper),
        rheology=factory.rheology(rheology),
        velocity_profile=velocity_strategy,
        inlet_boundary=factory.inlet_boundary(
            inlet, umax=inlet_umax, waveform_path=str(flow_waveform) if flow_waveform else None
        ),
        outlet_boundary=factory.outlet_boundary(
            outlet,
            reflection_coefficient=reflection_coefficient,
            reference_flow=reference_flow,
        ),
        initial_condition=ic,
        nx=nx,
        tfinal=tfinal,
        dt=dt,
        cfl=cfl,
        saveat=saveat,
        sample_times=sample_times,
        severity=severity,
        ic_pressure_drop_dyn_cm2=10.0 * ic_pressure_drop_pa,
        scipy_method=scipy_method,
        sciml_label=sciml_label,
        julia_project=julia_project,
        dtype=validate_dtype_name(dtype),
    )


def fail(exc: Exception) -> None:
    typer.echo(f"error: {exc}", err=True)
    raise typer.Exit(1) from exc


@app.callback()
def configure(
    log_level: str = typer.Option(
        "WARNING",
        "--log-level",
        help="Python logging level for operational telemetry on stderr.",
    )
) -> None:
    """Configure CLI logging."""

    try:
        configure_logging(log_level)
    except ValueError as exc:
        raise typer.BadParameter(str(exc), param_hint="--log-level") from exc


@app.command()
def devices() -> None:
    """Report available CPU/Torch devices."""

    emit_json({"devices": [item.__dict__ for item in detect_devices()]})


@app.command()
def descriptors(json_output: bool = typer.Option(False, "--json", help="Emit JSON instead of text.")) -> None:
    """List Julia-compatible descriptors."""

    payload = registry.as_dict()
    if json_output:
        emit_json(payload)
        return
    for category in registry.categories():
        typer.echo(f"{category}:")
        for item in registry.by_category(category):
            typer.echo(f"  {item.name} - {item.description}")


@app.command(name="run")
def run_command(
    out: Path = typer.Option(Path("python-output"), "--out", help="Output directory."),
    backend: str = typer.Option("native", "--backend", help="native, torch, scipy, or sciml-reference."),
    device: str = typer.Option("cpu", "--device", help="Torch device: cpu, mps, or cuda."),
    allow_cpu_fallback: bool = typer.Option(
        False, "--allow-cpu-fallback", help="Allow CPU fallback for unavailable Torch devices."
    ),
    model: str = typer.Option("canic-extended-1d", "--model", help="canic-extended-1d or classical-1d-no-slip."),
    space: str = typer.Option("fv-muscl", "--space", help="Spatial descriptor."),
    time_stepper: str = typer.Option("ssprk2", "--time-stepper", help="Time-stepper descriptor."),
    nx: int = typer.Option(64, "--nx", help="Number of cells."),
    tfinal: float = typer.Option(0.02, "--tfinal", help="Final time in seconds."),
    dt: float = typer.Option(1.0e-4, "--dt", help="Maximum time step."),
    cfl: float = typer.Option(0.35, "--cfl", help="CFL limit."),
    saveat: float = typer.Option(0.01, "--saveat", help="Output cadence."),
    sample_times_text: Optional[str] = typer.Option(
        None, "--sample-times", help="Comma-separated exact output times; must start at 0 and end at --tfinal."
    ),
    severity: float = typer.Option(50.0, "--severity", help="Stenosis severity percent."),
    dtype: str = typer.Option("auto", "--dtype", help="auto, float32, or float64."),
    rheology: str = typer.Option("newtonian", "--rheology", help="Rheology descriptor."),
    velocity_profile: str = typer.Option("parabolic", "--velocity-profile", help="flat, parabolic, or power."),
    profile_exponent: Optional[float] = typer.Option(None, "--profile-exponent", help="Power-profile exponent."),
    profile_shear_factor: float = typer.Option(4.0, "--profile-shear-factor", help="Flat-profile shear factor."),
    alpha: Optional[float] = typer.Option(
        None, "--alpha", help="Legacy-compatible power-profile alpha, 1 < alpha < 2."
    ),
    ic: str = typer.Option("geometry-rest", "--ic", help="geometry-rest or stationary-stokes."),
    ic_pressure_drop_pa: float = typer.Option(
        100.0, "--ic-pressure-drop-pa", help="Stationary-Stokes pressure drop in Pa."
    ),
    inlet: str = typer.Option("steady-velocity", "--inlet", help="steady-velocity or flow-waveform."),
    inlet_umax: float = typer.Option(45.0, "--inlet-umax", help="Steady inlet maximum velocity in cm/s."),
    flow_waveform: Optional[Path] = typer.Option(None, "--flow-waveform", help="Time/flow waveform file."),
    outlet: str = typer.Option("fixed-area-characteristic", "--outlet", help="Outlet descriptor."),
    reflection_coefficient: float = typer.Option(0.0, "--reflection-coefficient", help="Reflection coefficient Rt."),
    reference_flow: float = typer.Option(0.0, "--reference-flow", help="Reference outlet flow in cm^3/s."),
    scipy_method: str = typer.Option("RK45", "--scipy-method", help="SciPy solve_ivp method."),
    sciml_label: str = typer.Option("auto", "--sciml-label", help="SciML policy label."),
    julia_project: Optional[Path] = typer.Option(
        None, "--julia-project", help="Path to this Julia project for sciml-reference."
    ),
) -> None:
    """Run one deterministic solver case."""

    try:
        request = build_request(
            model=model,
            space=space,
            time_stepper=time_stepper,
            rheology=rheology,
            velocity_profile=velocity_profile,
            profile_exponent=profile_exponent,
            alpha=alpha,
            profile_shear_factor=profile_shear_factor,
            inlet=inlet,
            inlet_umax=inlet_umax,
            flow_waveform=flow_waveform,
            outlet=outlet,
            reflection_coefficient=reflection_coefficient,
            reference_flow=reference_flow,
            ic=ic,
            nx=nx,
            tfinal=tfinal,
            dt=dt,
            cfl=cfl,
            saveat=saveat,
            sample_times=parse_sample_times(sample_times_text),
            severity=severity,
            ic_pressure_drop_pa=ic_pressure_drop_pa,
            scipy_method=scipy_method,
            sciml_label=sciml_label,
            julia_project=julia_project,
            dtype=dtype,
        )
        result, selected_device = run_backend(request, backend, device=device, allow_cpu_fallback=allow_cpu_fallback)
        outputs = write_outputs(result, request, out, backend, selected_device)
        emit_json({"status": "ok", "summary": result.summary(), "outputs": outputs})
    except Exception as exc:
        fail(exc)


@app.command()
def verify(
    device: str = typer.Option("mps", "--device", help="Device to check."),
    run_smoke: bool = typer.Option(False, "--run-smoke/--no-run-smoke", help="Run a tiny Torch smoke check."),
    allow_cpu_fallback: bool = typer.Option(False, "--allow-cpu-fallback", help="Allow CPU fallback."),
) -> None:
    """Verify descriptors and optional Torch/MPS runtime."""

    payload: dict[str, object] = {
        "devices": [item.__dict__ for item in detect_devices()],
        "requested_device": device,
        "descriptors": {cat: [item.name for item in registry.by_category(cat)] for cat in registry.categories()},
    }
    if run_smoke:
        request = build_request(
            model="canic-extended-1d",
            space="fv-first-order",
            time_stepper="euler",
            rheology="newtonian",
            velocity_profile="parabolic",
            profile_exponent=None,
            alpha=None,
            profile_shear_factor=4.0,
            inlet="steady-velocity",
            inlet_umax=45.0,
            flow_waveform=None,
            outlet="fixed-area-characteristic",
            reflection_coefficient=0.0,
            reference_flow=0.0,
            ic="geometry-rest",
            nx=16,
            tfinal=0.001,
            dt=0.001,
            cfl=0.25,
            saveat=0.001,
            sample_times=None,
            severity=20.0,
            ic_pressure_drop_pa=100.0,
            scipy_method="RK45",
            sciml_label="auto",
            julia_project=None,
            dtype="auto",
        )
        try:
            result, selected = run_backend(request, "torch", device=device, allow_cpu_fallback=allow_cpu_fallback)
            payload["smoke"] = {"status": "ok", "device": selected, "steps": result.steps}
        except BackendUnavailable as exc:
            payload["smoke"] = {"status": "unavailable", "reason": str(exc)}
    emit_json(payload)


@app.command()
def compare(
    left_backend: str = typer.Option("native", "--left-backend", help="Left backend."),
    right_backend: str = typer.Option("native", "--right-backend", help="Right backend."),
    device: str = typer.Option("cpu", "--device", help="Torch device if either side uses --*-backend torch."),
    allow_cpu_fallback: bool = typer.Option(
        False, "--allow-cpu-fallback", help="Allow CPU fallback for unavailable Torch devices."
    ),
    model: str = typer.Option("canic-extended-1d", "--model", help="canic-extended-1d or classical-1d-no-slip."),
    space: str = typer.Option("fv-first-order", "--space", help="Spatial descriptor."),
    time_stepper: str = typer.Option("ssprk2", "--time-stepper", help="Time-stepper descriptor."),
    nx: int = typer.Option(24, "--nx", help="Number of cells."),
    tfinal: float = typer.Option(0.002, "--tfinal", help="Final time."),
    dt: float = typer.Option(0.001, "--dt", help="Maximum time step."),
    cfl: float = typer.Option(0.25, "--cfl", help="CFL limit."),
    saveat: float = typer.Option(0.001, "--saveat", help="Save interval."),
    sample_times_text: Optional[str] = typer.Option(
        None, "--sample-times", help="Comma-separated exact output times; must start at 0 and end at --tfinal."
    ),
    severity: float = typer.Option(30.0, "--severity", help="Stenosis severity percent."),
    dtype: str = typer.Option("auto", "--dtype", help="auto, float32, or float64."),
    rheology: str = typer.Option("newtonian", "--rheology", help="Rheology descriptor."),
    velocity_profile: str = typer.Option("parabolic", "--velocity-profile", help="flat, parabolic, or power."),
    profile_exponent: Optional[float] = typer.Option(None, "--profile-exponent", help="Power-profile exponent."),
    profile_shear_factor: float = typer.Option(4.0, "--profile-shear-factor", help="Flat-profile shear factor."),
    alpha: Optional[float] = typer.Option(
        None, "--alpha", help="Legacy-compatible power-profile alpha, 1 < alpha < 2."
    ),
    ic: str = typer.Option("geometry-rest", "--ic", help="geometry-rest or stationary-stokes."),
    ic_pressure_drop_pa: float = typer.Option(
        100.0, "--ic-pressure-drop-pa", help="Stationary-Stokes pressure drop in Pa."
    ),
    inlet: str = typer.Option("steady-velocity", "--inlet", help="steady-velocity or flow-waveform."),
    inlet_umax: float = typer.Option(45.0, "--inlet-umax", help="Steady inlet maximum velocity in cm/s."),
    flow_waveform: Optional[Path] = typer.Option(None, "--flow-waveform", help="Time/flow waveform file."),
    outlet: str = typer.Option("fixed-area-characteristic", "--outlet", help="Outlet descriptor."),
    reflection_coefficient: float = typer.Option(0.0, "--reflection-coefficient", help="Reflection coefficient Rt."),
    reference_flow: float = typer.Option(0.0, "--reference-flow", help="Reference outlet flow in cm^3/s."),
    scipy_method: str = typer.Option("RK45", "--scipy-method", help="SciPy solve_ivp method."),
    sciml_label: str = typer.Option("auto", "--sciml-label", help="SciML policy label."),
    julia_project: Optional[Path] = typer.Option(
        None, "--julia-project", help="Path to this Julia project for sciml-reference."
    ),
) -> None:
    """Compare compact metrics between two backend adapters."""

    try:
        request = build_request(
            model=model,
            space=space,
            time_stepper=time_stepper,
            rheology=rheology,
            velocity_profile=velocity_profile,
            profile_exponent=profile_exponent,
            alpha=alpha,
            profile_shear_factor=profile_shear_factor,
            inlet=inlet,
            inlet_umax=inlet_umax,
            flow_waveform=flow_waveform,
            outlet=outlet,
            reflection_coefficient=reflection_coefficient,
            reference_flow=reference_flow,
            ic=ic,
            nx=nx,
            tfinal=tfinal,
            dt=dt,
            cfl=cfl,
            saveat=saveat,
            sample_times=parse_sample_times(sample_times_text),
            severity=severity,
            ic_pressure_drop_pa=ic_pressure_drop_pa,
            scipy_method=scipy_method,
            sciml_label=sciml_label,
            julia_project=julia_project,
            dtype=dtype,
        )
        emit_json(
            compare_backends(
                request,
                left_backend,
                right_backend,
                device=device,
                allow_cpu_fallback=allow_cpu_fallback,
            )
        )
    except Exception as exc:
        fail(exc)


@app.command(name="run-manifest")
def run_manifest_command(
    manifest: Path = typer.Argument(..., help="Run manifest generated by research-hemodynamics run or experiment."),
    out: Optional[Path] = typer.Option(None, "--out", help="Output directory for the rerun."),
) -> None:
    """Rerun one manifest without changing solver options."""

    try:
        payload, request, backend, device = load_manifest(manifest)
        output_dir = out or (manifest.parent / "rerun")
        result, selected_device = run_backend(request, backend, device=device)
        outputs = write_outputs(
            result,
            request,
            output_dir,
            backend,
            selected_device,
            experiment_id=str(payload.get("experiment_id", "manual")),
            case_id=str(payload.get("case_id", output_dir.name)),
        )
        emit_json({"status": "ok", "manifest": str(manifest), "summary": result.summary(), "outputs": outputs})
    except Exception as exc:
        fail(exc)


@app.command(name="experiment")
def experiment_command(
    experiment: str = typer.Option("backend-parity-v1", "--experiment", help="Experiment identifier."),
    profile: str = typer.Option("smoke", "--profile", help="smoke or full."),
    out: Path = typer.Option(Path("tmp/experiments/backend-parity-v1"), "--out", help="Experiment output root."),
    overwrite: bool = typer.Option(False, "--overwrite/--no-overwrite", help="Replace an existing output root."),
    include_mps: bool = typer.Option(True, "--include-mps/--no-include-mps", help="Include Torch MPS cases."),
) -> None:
    """Run a reproducible backend-parity experiment matrix."""

    try:
        if experiment != "backend-parity-v1":
            raise ValueError("--experiment currently supports only backend-parity-v1")
        emit_json(run_backend_parity_experiment(profile=profile, out=out, overwrite=overwrite, include_mps=include_mps))
    except Exception as exc:
        fail(exc)


def main() -> None:
    app()


if __name__ == "__main__":
    main()
