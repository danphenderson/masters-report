"""Experiment orchestration for reproducible backend-parity studies."""

from __future__ import annotations

import csv
import shutil
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter
from typing import Any

from .backends import BackendUnavailable, run_backend
from .descriptors import DescriptorFactory, registry
from .numerics import (
    RunRequest,
    canonical_hash,
    canonical_json,
    field_parity_metrics,
    request_manifest,
    resolve_dtype_name,
    result_diagnostics,
    total_variation_series,
    write_outputs,
)

EXPERIMENT_ID = "backend-parity-v1"


@dataclass(frozen=True)
class ExperimentCase:
    case_id: str
    model: str
    severity: float
    nx: int
    space: str
    time_stepper: str
    backend: str
    device: str
    dtype: str

    @property
    def reference_key(self) -> tuple[str, float, int, str, str]:
        return self.model, self.severity, self.nx, self.space, self.time_stepper


def severity_token(severity: float) -> str:
    return f"S{int(round(severity)):02d}"


def case_id(case: ExperimentCase) -> str:
    return (
        f"{case.model}_{severity_token(case.severity)}_N{case.nx}_{case.space}_{case.time_stepper}_"
        f"{case.backend}_{case.device}_{case.dtype}"
    )


def profile_config(profile: str) -> dict[str, Any]:
    normalized = profile.strip().lower()
    if normalized == "smoke":
        return {
            "profile": "smoke",
            "severities": [0.0, 40.0],
            "nxs": [24],
            "tfinal": 1.0e-3,
            "dt": 1.0e-3,
            "cfl": 0.25,
            "sample_times": [0.0, 1.0e-3],
        }
    if normalized == "full":
        return {
            "profile": "full",
            "severities": [0.0, 23.0, 40.0, 50.0],
            "nxs": [100, 200, 400, 800],
            "tfinal": 1.0,
            "dt": 1.0e-5,
            "cfl": 0.45,
            "sample_times": [0.0, 0.25, 0.5, 0.75, 1.0],
        }
    raise ValueError("--profile must be smoke or full")


def experiment_cases(profile: str, *, include_mps: bool = True) -> list[ExperimentCase]:
    config = profile_config(profile)
    method_matrix = [
        ("fv-first-order", "euler", "native", "cpu", "float64"),
        ("fv-first-order", "ssprk3", "native", "cpu", "float64"),
        ("fv-muscl", "ssprk3", "native", "cpu", "float64"),
        ("fv-first-order", "ssprk3", "torch", "cpu", "float64"),
        ("fv-muscl", "ssprk3", "torch", "cpu", "float64"),
    ]
    if include_mps:
        method_matrix.append(("fv-muscl", "ssprk3", "torch", "mps", "float32"))
    cases: list[ExperimentCase] = []
    for model in ("canic-extended-1d", "classical-1d-no-slip"):
        for severity in config["severities"]:
            for nx in config["nxs"]:
                for space, stepper, backend, device, dtype in method_matrix:
                    template = ExperimentCase("", model, severity, nx, space, stepper, backend, device, dtype)
                    cases.append(
                        ExperimentCase(case_id(template), model, severity, nx, space, stepper, backend, device, dtype)
                    )
    return cases


def request_for_case(case: ExperimentCase, profile: str) -> RunRequest:
    config = profile_config(profile)
    factory = DescriptorFactory(registry)
    sample_times = tuple(float(value) for value in config["sample_times"])
    return RunRequest(
        model=factory.forward_model(case.model),
        spatial=factory.spatial(case.space),
        time_stepper=factory.time_stepper(case.time_stepper),
        rheology=factory.rheology("newtonian"),
        velocity_profile=factory.velocity_profile("parabolic"),
        inlet_boundary=factory.inlet_boundary("steady-velocity", umax=45.0),
        outlet_boundary=factory.outlet_boundary("fixed-area-characteristic"),
        initial_condition="geometry-rest",
        nx=case.nx,
        tfinal=float(config["tfinal"]),
        dt=float(config["dt"]),
        cfl=float(config["cfl"]),
        saveat=float(config["tfinal"]),
        sample_times=sample_times,
        severity=case.severity,
        dtype=case.dtype,
    )


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in fieldnames})


def parity_tolerance(case: ExperimentCase) -> float:
    if case.backend == "torch" and case.device == "mps":
        return 1.0e-3
    if case.backend == "torch" and case.dtype == "float64":
        return 1.0e-8
    return 1.0e-8


def run_backend_parity_experiment(
    *,
    profile: str,
    out: Path,
    overwrite: bool = False,
    include_mps: bool = True,
) -> dict[str, Any]:
    config = profile_config(profile)
    if out.exists():
        if not overwrite:
            raise ValueError(f"output directory exists; pass --overwrite to replace it: {out}")
        shutil.rmtree(out)
    runs_dir = out / "runs"
    manifests_dir = out / "manifests"
    summaries_dir = out / "summaries"
    runs_dir.mkdir(parents=True)
    manifests_dir.mkdir(parents=True)
    summaries_dir.mkdir(parents=True)

    run_rows: list[dict[str, Any]] = []
    parity_rows: list[dict[str, Any]] = []
    performance_rows: list[dict[str, Any]] = []
    variation_rows: list[dict[str, Any]] = []
    successful: dict[str, tuple[ExperimentCase, RunRequest, Any, dict[str, str], dict[str, Any], float]] = {}
    references: dict[tuple[str, float, int, str, str], str] = {}

    for case in experiment_cases(profile, include_mps=include_mps):
        request = request_for_case(case, profile)
        run_dir = runs_dir / case.case_id
        started = perf_counter()
        try:
            result, selected_device = run_backend(request, case.backend, device=case.device)
            elapsed = perf_counter() - started
            outputs = write_outputs(
                result,
                request,
                run_dir,
                case.backend,
                selected_device,
                experiment_id=EXPERIMENT_ID,
                case_id=case.case_id,
            )
            manifest_copy = manifests_dir / f"{case.case_id}.json"
            shutil.copyfile(outputs["manifest_json"], manifest_copy)
            diagnostics = result_diagnostics(result, request)
            dtype_name = str(result.metadata.get("dtype") or resolve_dtype_name(request, case.backend, selected_device))
            row = {
                "case_id": case.case_id,
                "status": "ok",
                "error_message": "",
                "backend": case.backend,
                "device": selected_device,
                "dtype": dtype_name,
                "model": case.model,
                "space": case.space,
                "time_stepper": case.time_stepper,
                "nx": case.nx,
                "severity": case.severity,
                "tfinal": request.tfinal,
                "dt": request.dt,
                "cfl": request.cfl,
                "steps": result.steps,
                "finite_state": diagnostics["finite_state"],
                "positivity_pass": diagnostics["positivity_pass"],
                "min_a": diagnostics["min_a"],
                "max_speed": diagnostics["max_speed"],
                "dt_min": diagnostics["dt_min"],
                "dt_max": diagnostics["dt_max"],
                "dt_mean": diagnostics["dt_mean"],
                "runtime_seconds": elapsed,
                "manifest_hash": outputs["manifest_hash"],
                "output_hash": outputs["output_hash"],
                "run_dir": str(run_dir),
            }
            run_rows.append(row)
            successful[case.case_id] = (case, request, result, outputs, diagnostics, elapsed)
            if case.backend == "native" and case.device == "cpu" and dtype_name == "float64":
                references.setdefault(case.reference_key, case.case_id)
            throughput = case.nx * result.steps / elapsed if elapsed > 0.0 else 0.0
            performance_rows.append(
                {
                    "case_id": case.case_id,
                    "backend": case.backend,
                    "device": selected_device,
                    "dtype": dtype_name,
                    "model": case.model,
                    "nx": case.nx,
                    "severity": case.severity,
                    "steps": result.steps,
                    "runtime_seconds": elapsed,
                    "time_per_step": elapsed / result.steps if result.steps else "",
                    "throughput_cells_steps_per_s": throughput,
                    "status": "ok",
                    "error_message": "",
                }
            )
            tv = total_variation_series(result)
            tv_initial = float(tv[0]) if tv.size else 0.0
            tv_final = float(tv[-1]) if tv.size else 0.0
            variation_rows.append(
                {
                    "case_id": case.case_id,
                    "severity": case.severity,
                    "nx": case.nx,
                    "model": case.model,
                    "space": case.space,
                    "backend": case.backend,
                    "device": selected_device,
                    "dtype": dtype_name,
                    "tv_kind": "velocity_total_variation_diagnostic",
                    "tv_initial": tv_initial,
                    "tv_final": tv_final,
                    "tv_max": float(tv.max()) if tv.size else 0.0,
                    "tv_ratio_final_to_initial": tv_final / (tv_initial + 1.0e-300),
                    "status": "ok",
                    "error_message": "",
                }
            )
        except BackendUnavailable as exc:
            run_rows.append(error_row(case, request, "skipped", str(exc)))
        except Exception as exc:
            run_rows.append(error_row(case, request, "error", str(exc)))

    for test_case_id, (test_case, _request, test_result, _outputs, _diagnostics, _elapsed) in successful.items():
        if test_case.backend == "native":
            continue
        reference_id = references.get(test_case.reference_key)
        if reference_id is None:
            parity_rows.append(
                {
                    "case_id": test_case_id,
                    "comparison": "native-reference-missing",
                    "model": test_case.model,
                    "field": "",
                    "linf": "",
                    "l2": "",
                    "rel_l2": "",
                    "tolerance": "",
                    "pass": "",
                    "status": "skipped",
                    "error_message": "no matching native cpu float64 reference",
                }
            )
            continue
        ref_case, _ref_request, ref_result, _ref_outputs, _ref_diagnostics, _ref_elapsed = successful[reference_id]
        comparison = (
            f"{test_case.model}_{test_case.backend}-{test_case.device}-{test_case.dtype}_vs_"
            f"{ref_case.backend}-{ref_case.device}-float64"
        )
        tolerance = parity_tolerance(test_case)
        try:
            metrics = field_parity_metrics(ref_result, test_result)
            for field, values in metrics.items():
                parity_rows.append(
                    {
                        "case_id": test_case_id,
                        "reference_case_id": reference_id,
                        "comparison": comparison,
                        "severity": test_case.severity,
                        "nx": test_case.nx,
                        "model": test_case.model,
                        "space": test_case.space,
                        "time_stepper": test_case.time_stepper,
                        "field": field,
                        "linf": values["linf"],
                        "l2": values["l2"],
                        "rel_l2": values["rel_l2"],
                        "tolerance": tolerance,
                        "pass": values["rel_l2"] <= tolerance,
                        "status": "ok",
                        "error_message": "",
                    }
                )
        except Exception as exc:
            parity_rows.append(
                {
                    "case_id": test_case_id,
                    "reference_case_id": reference_id,
                    "comparison": comparison,
                    "model": test_case.model,
                    "status": "error",
                    "error_message": str(exc),
                }
            )

    run_summary_path = summaries_dir / "run_summary.csv"
    parity_summary_path = summaries_dir / "parity_summary.csv"
    performance_summary_path = summaries_dir / "performance_summary.csv"
    variation_summary_path = summaries_dir / "variation_summary.csv"
    write_csv(
        run_summary_path,
        run_rows,
        [
            "case_id",
            "status",
            "error_message",
            "backend",
            "device",
            "dtype",
            "model",
            "space",
            "time_stepper",
            "nx",
            "severity",
            "tfinal",
            "dt",
            "cfl",
            "steps",
            "finite_state",
            "positivity_pass",
            "min_a",
            "max_speed",
            "dt_min",
            "dt_max",
            "dt_mean",
            "runtime_seconds",
            "manifest_hash",
            "output_hash",
            "run_dir",
        ],
    )
    write_csv(
        parity_summary_path,
        parity_rows,
        [
            "case_id",
            "reference_case_id",
            "comparison",
            "severity",
            "nx",
            "model",
            "space",
            "time_stepper",
            "field",
            "linf",
            "l2",
            "rel_l2",
            "tolerance",
            "pass",
            "status",
            "error_message",
        ],
    )
    write_csv(
        performance_summary_path,
        performance_rows,
        [
            "case_id",
            "backend",
            "device",
            "dtype",
            "model",
            "nx",
            "severity",
            "steps",
            "runtime_seconds",
            "time_per_step",
            "throughput_cells_steps_per_s",
            "status",
            "error_message",
        ],
    )
    write_csv(
        variation_summary_path,
        variation_rows,
        [
            "case_id",
            "severity",
            "nx",
            "model",
            "space",
            "backend",
            "device",
            "dtype",
            "tv_kind",
            "tv_initial",
            "tv_final",
            "tv_max",
            "tv_ratio_final_to_initial",
            "status",
            "error_message",
        ],
    )
    experiment_manifest = {
        "experiment_id": EXPERIMENT_ID,
        "profile": config["profile"],
        "output_dir": str(out),
        "case_count": len(run_rows),
        "ok_count": sum(1 for row in run_rows if row.get("status") == "ok"),
        "summaries": {
            "run_summary": str(run_summary_path),
            "parity_summary": str(parity_summary_path),
            "performance_summary": str(performance_summary_path),
            "variation_summary": str(variation_summary_path),
        },
        "cases": [row["case_id"] for row in run_rows],
    }
    experiment_manifest_path = out / "experiment_manifest.json"
    experiment_manifest_path.write_text(canonical_json(experiment_manifest, pretty=True) + "\n")
    return {"status": "ok", "manifest": str(experiment_manifest_path), **experiment_manifest}


def error_row(case: ExperimentCase, request: RunRequest, status: str, message: str) -> dict[str, Any]:
    manifest = request_manifest(
        request,
        case.backend,
        case.device,
        request.dtype,
        experiment_id=EXPERIMENT_ID,
        case_id=case.case_id,
    )
    return {
        "case_id": case.case_id,
        "status": status,
        "error_message": message,
        "backend": case.backend,
        "device": case.device,
        "dtype": case.dtype,
        "model": case.model,
        "space": case.space,
        "time_stepper": case.time_stepper,
        "nx": case.nx,
        "severity": case.severity,
        "tfinal": request.tfinal,
        "dt": request.dt,
        "cfl": request.cfl,
        "manifest_hash": canonical_hash(manifest),
    }
