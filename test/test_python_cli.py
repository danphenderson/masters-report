import json
from pathlib import Path

import pytest
from research_hemodynamics.backends import compare_backends, run_backend
from research_hemodynamics.cli import app, build_request
from research_hemodynamics.descriptors import DescriptorFactory, registry
from typer.testing import CliRunner

RUNNER = CliRunner()


def request(space: str = "fv-first-order"):
    return build_request(
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


@pytest.mark.parametrize("space", ["fv-first-order", "fv-muscl", "fv-lax-wendroff", "dg-p0", "dg-p1", "dg-p2"])
def test_fvm_and_dg_smoke(space: str) -> None:
    result, _ = run_backend(request(space), "native")
    assert result.area.shape == (24, 3)
    assert result.summary()["area_min"] > 0.0


def test_fem_projection_smoke() -> None:
    result, _ = run_backend(request("fem-stationary-stokes"), "native")
    assert result.area.shape == (24, 3)
    assert result.metadata["mode"] == "stationary-stokes-projection"
    assert float(result.flow.mean()) > 0.0


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
    for option in ["--device", "--allow-cpu-fallback", "--scipy-method", "--sciml-label", "--julia-project"]:
        assert option in result.output


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
