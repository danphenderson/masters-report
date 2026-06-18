import json
import logging
from io import StringIO
from pathlib import Path

import numpy as np
import pytest
from research_hemodynamics.backends import compare_backends, run_backend
from research_hemodynamics.cli import app, build_request
from research_hemodynamics.descriptors import DescriptorFactory, registry
from research_hemodynamics.logging import PACKAGE_LOGGER_NAME, configure_logging, event_fields
from research_hemodynamics.numerics import (
    AREA_LIMITER_FLOOR,
    flux,
    lax_wendroff_flux,
    lax_wendroff_interface_state,
    write_outputs,
)
from typer.testing import CliRunner

RUNNER = CliRunner()


def request(space: str = "fv-first-order", **overrides):
    params = dict(
        space=space,
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
        nx=24,
        tfinal=0.002,
        dt=0.001,
        cfl=0.25,
        saveat=0.001,
        severity=30.0,
        ic_pressure_drop_pa=100.0,
        scipy_method="RK45",
        sciml_label="auto",
        julia_project=None,
    )
    params.update(overrides)
    return build_request(**params)


def test_descriptor_registry_covers_julia_surface() -> None:
    expected = {
        "spatial": {
            "fv-first-order",
            "fv-muscl",
            "fv-lax-wendroff",
            "dg-p0",
            "dg-p1",
            "dg-p2",
            "fem-stationary-stokes",
        },
        "limiter": {"minmod"},
        "time-stepper": {"euler", "ssprk2", "ssprk3"},
        "backend": {"native", "torch", "scipy", "sciml-reference"},
        "scipy-method": {"RK45", "DOP853", "Radau", "BDF", "LSODA"},
        "sciml-label": {"auto", "tsit5", "rodas5p", "ssprk"},
        "rheology": {"newtonian", "carreau", "carreau-yasuda", "casson", "power-law"},
        "velocity-profile": {"flat", "parabolic", "power"},
        "initial-condition": {"geometry-rest", "stationary-stokes"},
        "inlet-boundary": {"steady-velocity", "flow-waveform"},
        "outlet-boundary": {"fixed-area-characteristic", "reflection-coefficient"},
    }
    for category, names in expected.items():
        assert {item.name for item in registry.by_category(category)} >= names


def test_descriptor_json_exposes_python_maturity_tiers() -> None:
    result = RUNNER.invoke(app, ["descriptors", "--json"])
    assert result.exit_code == 0
    payload = json.loads(result.output)
    spatial = {item["name"]: item["metadata"] for item in payload["spatial"]}
    for name in ["fv-first-order", "fv-muscl", "fv-lax-wendroff", "fem-stationary-stokes"]:
        assert spatial[name]["tier"] == "publication"
        assert spatial[name].get("fallback") is None
    for name in ["dg-p0", "dg-p1", "dg-p2"]:
        assert spatial[name]["tier"] == "experimental-smoke"
        assert spatial[name]["scientific_tier"] == "julia-reference-only"
        assert spatial[name]["fallback"] == "cell-average-fv-update"
    tier_values = {metadata["tier"] for metadata in spatial.values()}
    tier_values |= {metadata["scientific_tier"] for metadata in spatial.values() if "scientific_tier" in metadata}
    assert {"publication", "experimental-smoke", "julia-reference-only"} <= tier_values
    for metadata in spatial.values():
        assert not (metadata.get("tier") == "publication" and metadata.get("fallback"))


def test_cli_help_has_commands_and_no_fno() -> None:
    result = RUNNER.invoke(app, ["--help"])
    assert result.exit_code == 0
    for command in ["devices", "descriptors", "run", "verify", "compare"]:
        assert command in result.output
    assert "fno" not in result.output.lower()
    assert "operator" not in result.output.lower()


def test_devices_reports_cpu_and_mps_status_without_requiring_mps() -> None:
    result = RUNNER.invoke(app, ["devices"])
    assert result.exit_code == 0
    payload = json.loads(result.output)
    assert any(device["name"] == "cpu" for device in payload["devices"])
    assert any(device["name"] == "mps" for device in payload["devices"])


def test_native_minimal_run_writes_outputs(tmp_path: Path) -> None:
    result = RUNNER.invoke(
        app,
        [
            "run",
            "--out",
            str(tmp_path),
            "--space",
            "fv-first-order",
            "--time-stepper",
            "euler",
            "--nx",
            "24",
            "--tfinal",
            "0.002",
            "--saveat",
            "0.001",
        ],
    )
    assert result.exit_code == 0, result.output
    assert (tmp_path / "summary.json").exists()
    assert (tmp_path / "series.csv").exists()
    assert (tmp_path / "solution.npz").exists()
    payload = json.loads((tmp_path / "summary.json").read_text())
    assert payload["metadata"]["spatial"]["descriptor"] == "fv-first-order"


def test_event_fields_filters_stdlib_reserved_message_keys() -> None:
    fields = event_fields(event="logging_test", message="reserved", asctime="reserved", backend="native")
    assert fields == {"event": "logging_test", "backend": "native"}
    logging.getLogger(PACKAGE_LOGGER_NAME).info("record accepts filtered fields", extra=fields)


def test_configure_logging_uses_single_nonpropagating_cli_handler(capsys: pytest.CaptureFixture[str]) -> None:
    logger = logging.getLogger(PACKAGE_LOGGER_NAME)
    root = logging.getLogger()
    original_handlers = list(logger.handlers)
    original_level = logger.level
    original_propagate = logger.propagate
    original_root_level = root.level
    root_stream = StringIO()
    root_handler = logging.StreamHandler(root_stream)
    root.addHandler(root_handler)
    root.setLevel(logging.INFO)
    try:
        configure_logging("INFO")
        configure_logging("INFO")
        logger.info("single cli handler")
        captured = capsys.readouterr()
        assert captured.err.count("single cli handler") == 1
        assert root_stream.getvalue() == ""
        assert logger.propagate is False
    finally:
        logger.handlers = original_handlers
        logger.setLevel(original_level)
        logger.propagate = original_propagate
        root.removeHandler(root_handler)
        root.setLevel(original_root_level)


def test_backend_and_output_logging_uses_standard_records(tmp_path: Path, caplog: pytest.LogCaptureFixture) -> None:
    logger = logging.getLogger(PACKAGE_LOGGER_NAME)
    original_handlers = list(logger.handlers)
    original_level = logger.level
    original_propagate = logger.propagate
    logger.handlers = []
    logger.propagate = True
    req = request("fv-first-order")
    try:
        caplog.set_level(logging.INFO, logger=PACKAGE_LOGGER_NAME)
        result, selected = run_backend(req, "native")
        outputs = write_outputs(result, req, tmp_path, "native", selected)
        assert Path(outputs["summary_json"]).exists()
        events = {getattr(record, "event", None): record for record in caplog.records}
        assert {"backend_started", "native_completed", "backend_completed", "outputs_written"} <= set(events)
        assert events["backend_completed"].backend == "native"
        assert events["backend_completed"].method == "fv-first-order"
        assert events["backend_completed"].status == "ok"
        assert events["outputs_written"].output_dir == str(tmp_path)
    finally:
        logger.handlers = original_handlers
        logger.setLevel(original_level)
        logger.propagate = original_propagate


def test_cli_info_logging_stays_on_stderr_and_stdout_remains_json(tmp_path: Path) -> None:
    result = RUNNER.invoke(
        app,
        [
            "--log-level",
            "INFO",
            "run",
            "--out",
            str(tmp_path),
            "--space",
            "fv-first-order",
            "--time-stepper",
            "euler",
            "--nx",
            "24",
            "--tfinal",
            "0.002",
            "--saveat",
            "0.001",
        ],
    )
    assert result.exit_code == 0, result.output
    payload = json.loads(result.stdout)
    assert payload["status"] == "ok"
    assert "backend completed" in result.stderr
    assert "backend completed" not in result.stdout


def test_lax_wendroff_descriptor_dispatches_to_true_lw() -> None:
    strategy = DescriptorFactory(registry).spatial("fv-lax-wendroff")
    assert strategy.native_scheme == "lax-wendroff"
    assert strategy.fallback is None
    assert strategy.metadata()["tier"] == "publication"


def test_lax_wendroff_interface_prediction_matches_richtmyer_formula() -> None:
    req = request("fv-lax-wendroff")
    al, ql = 0.030, 0.010
    ar, qr = 0.031, 0.011
    z = 3.0
    dx = 0.25
    dt = 1.0e-6
    fa_l, fq_l = flux(np.asarray([al]), np.asarray([ql]), np.asarray([z]), req)
    fa_r, fq_r = flux(np.asarray([ar]), np.asarray([qr]), np.asarray([z]), req)
    ah, qh, usable = lax_wendroff_interface_state(al, ql, ar, qr, z, dx, dt, req)
    assert usable
    assert ah == pytest.approx(0.5 * (al + ar) - 0.5 * dt / dx * (fa_r[0] - fa_l[0]))
    assert qh == pytest.approx(0.5 * (ql + qr) - 0.5 * dt / dx * (fq_r[0] - fq_l[0]))


def test_lax_wendroff_invalid_half_state_uses_positive_fallback() -> None:
    req = request("fv-lax-wendroff")
    ah, _qh, usable = lax_wendroff_interface_state(0.01, 0.0, 2.0, 100.0, 3.0, 0.01, 1.0, req)
    assert not usable
    assert ah == pytest.approx(AREA_LIMITER_FLOOR)
    fa, fq = lax_wendroff_flux(0.01, 0.0, 2.0, 100.0, 3.0, 0.01, 1.0, req)
    assert np.isfinite([fa, fq]).all()


@pytest.mark.parametrize("space", ["fv-first-order", "fv-muscl", "fv-lax-wendroff", "dg-p0", "dg-p1", "dg-p2"])
def test_fvm_and_dg_smoke(space: str) -> None:
    result, _ = run_backend(request(space), "native")
    assert result.area.shape == (24, 3)
    assert result.summary()["area_min"] > 0.0


def test_fem_projection_smoke() -> None:
    result, _ = run_backend(request("fem-stationary-stokes"), "native")
    assert result.area.shape == (24, 3)
    assert result.metadata["mode"] == "stationary-stokes-projection"
    assert len(result.metadata["projection_hash"]) == 64
    assert float(result.flow.mean()) > 0.0


def test_fem_projection_is_deterministic_and_finite() -> None:
    req = request("fem-stationary-stokes", ic="stationary-stokes", severity=40.0, ic_pressure_drop_pa=40.0)
    left, _ = run_backend(req, "native")
    right, _ = run_backend(req, "native")
    assert left.metadata["projection_hash"] == right.metadata["projection_hash"]
    assert np.allclose(left.area, right.area)
    assert np.allclose(left.flow, right.flow)
    assert np.all(np.isfinite(left.pressure))
    assert float(np.min(left.area)) > 0.0


def test_compare_native_native() -> None:
    payload = compare_backends(request(), "native", "native")
    assert payload["relative_difference"]["area_mean_final"] == pytest.approx(0.0)
    assert payload["relative_difference"]["flow_mean_final"] == pytest.approx(0.0)


def test_torch_backend_uses_torch_native_rhs_metadata() -> None:
    torch = pytest.importorskip("torch")
    _ = torch
    result, selected = run_backend(request(), "torch", device="cpu")
    assert selected == "cpu"
    assert result.metadata["mode"] == "torch-tensor-update"
    assert result.metadata["rhs"] == "torch-native"


@pytest.mark.parametrize("space", ["fv-first-order", "fv-muscl", "fv-lax-wendroff"])
def test_torch_cpu_matches_numpy_for_publication_fvm(space: str) -> None:
    pytest.importorskip("torch")
    payload = compare_backends(request(space), "native", "torch", device="cpu")
    for key in ["area_mean_final", "flow_mean_final", "pressure_mean_final", "velocity_max"]:
        assert payload["relative_difference"][key] <= 1.0e-10


@pytest.mark.parametrize("space", ["fv-first-order", "fv-muscl", "fv-lax-wendroff"])
def test_torch_mps_matches_numpy_for_publication_fvm_when_available(space: str) -> None:
    torch = pytest.importorskip("torch")
    if not torch.backends.mps.is_available():
        pytest.skip("Torch MPS is not available")
    req = request(space, nx=64, tfinal=0.002, dt=0.001, saveat=0.002)
    payload = compare_backends(req, "native", "torch", device="mps")
    for key in ["area_mean_final", "flow_mean_final", "pressure_mean_final", "velocity_max"]:
        assert payload["relative_difference"][key] <= 1.0e-3


def test_torch_cli_run_writes_outputs_on_cpu(tmp_path: Path) -> None:
    pytest.importorskip("torch")
    result = RUNNER.invoke(
        app,
        [
            "run",
            "--backend",
            "torch",
            "--device",
            "cpu",
            "--out",
            str(tmp_path),
            "--space",
            "fv-first-order",
            "--time-stepper",
            "euler",
            "--nx",
            "24",
            "--tfinal",
            "0.002",
            "--saveat",
            "0.001",
        ],
    )
    assert result.exit_code == 0, result.output
    payload = json.loads((tmp_path / "summary.json").read_text())
    assert payload["metadata"]["mode"] == "torch-tensor-update"
    assert payload["metadata"]["rhs"] == "torch-native"
    assert (tmp_path / "series.csv").exists()
    assert (tmp_path / "solution.npz").exists()


def test_compare_command_exposes_documented_backend_options() -> None:
    result = RUNNER.invoke(app, ["compare", "--help"])
    assert result.exit_code == 0
    for option in [
        "--device",
        "--allow-cpu-fallback",
        "--time-stepper",
        "--dt",
        "--cfl",
        "--severity",
        "--rheology",
        "--velocity-profile",
        "--inlet",
        "--outlet",
        "--ic",
        "--scipy-method",
        "--sciml-label",
        "--julia-project",
    ]:
        assert option in result.output


def test_compare_command_accepts_run_descriptor_options() -> None:
    result = RUNNER.invoke(
        app,
        [
            "compare",
            "--left-backend",
            "native",
            "--right-backend",
            "native",
            "--space",
            "fv-lax-wendroff",
            "--time-stepper",
            "ssprk2",
            "--rheology",
            "carreau",
            "--velocity-profile",
            "flat",
            "--inlet",
            "steady-velocity",
            "--outlet",
            "fixed-area-characteristic",
            "--nx",
            "24",
            "--tfinal",
            "0.002",
            "--dt",
            "0.001",
            "--cfl",
            "0.25",
            "--saveat",
            "0.001",
            "--severity",
            "40",
        ],
    )
    assert result.exit_code == 0, result.output
    payload = json.loads(result.output)
    assert payload["relative_difference"]["area_mean_final"] == pytest.approx(0.0)


def test_boundary_strategy_metadata(tmp_path: Path) -> None:
    waveform = tmp_path / "waveform.txt"
    waveform.write_text("0.0 0.001\n0.1 0.001\n")
    result = RUNNER.invoke(
        app,
        [
            "run",
            "--out",
            str(tmp_path / "out"),
            "--nx",
            "24",
            "--tfinal",
            "0.002",
            "--saveat",
            "0.001",
            "--inlet",
            "flow-waveform",
            "--flow-waveform",
            str(waveform),
            "--outlet",
            "reflection-coefficient",
            "--reflection-coefficient",
            "0.25",
        ],
    )
    assert result.exit_code == 0, result.output
    payload = json.loads((tmp_path / "out" / "summary.json").read_text())
    assert payload["metadata"]["inlet_boundary"]["descriptor"] == "flow-waveform"
    assert payload["metadata"]["inlet_boundary"]["waveform_path"] == str(waveform)
    assert payload["metadata"]["outlet_boundary"]["descriptor"] == "reflection-coefficient"
    assert payload["metadata"]["outlet_boundary"]["reflection_coefficient"] == pytest.approx(0.25)


def test_alpha_factory_support() -> None:
    profile = DescriptorFactory(registry).velocity_profile("power", alpha=4.0 / 3.0)
    assert profile.exponent == pytest.approx(2.0)
    assert profile.momentum_alpha == pytest.approx(4.0 / 3.0)


def test_readme_command_coverage() -> None:
    readme = Path("README.md").read_text()
    for text in [
        "pipenv run python -m pip install -e .",
        "research-hemodynamics devices",
        "research-hemodynamics descriptors",
        "research-hemodynamics run",
        "research-hemodynamics verify --device mps --run-smoke",
        "research-hemodynamics compare",
        "fv-first-order",
        "fv-muscl",
        "fv-lax-wendroff",
        "dg-p0",
        "dg-p1",
        "dg-p2",
        "fem-stationary-stokes",
        "sciml-reference",
        "No FNO or operator-learning modules",
    ]:
        assert text in readme
