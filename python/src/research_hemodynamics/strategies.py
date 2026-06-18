"""Strategy objects for descriptor-selected solver behavior."""

from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np

from .descriptors import EXPERIMENTAL_SMOKE_TIER, JULIA_REFERENCE_ONLY_TIER, PUBLICATION_TIER, normalize_name

ArrayPair = tuple[np.ndarray, np.ndarray]
Rhs = Callable[[np.ndarray, np.ndarray, float, float], ArrayPair]


@dataclass(frozen=True)
class ForwardModelStrategy:
    descriptor: str
    wall: str
    wall_boundary_condition: str
    variable_radius_terms: bool
    requires_parabolic_profile: bool = False
    tier: str = PUBLICATION_TIER

    def metadata(self) -> dict[str, object]:
        return {
            "descriptor": self.descriptor,
            "wall": self.wall,
            "wall_boundary_condition": self.wall_boundary_condition,
            "variable_radius_terms": self.variable_radius_terms,
            "requires_parabolic_profile": self.requires_parabolic_profile,
            "tier": self.tier,
        }


def forward_model_strategy(name: str) -> ForwardModelStrategy:
    normalized = normalize_name(name)
    if normalized == "canic-extended-1d":
        return ForwardModelStrategy(
            normalized,
            "elastic1d",
            "reduced-elastic-wall-law",
            variable_radius_terms=True,
        )
    if normalized == "classical-1d-no-slip":
        return ForwardModelStrategy(
            normalized,
            "elastic1d",
            "no-slip-on-wall-Gamma_w-not-inlet-or-outlet",
            variable_radius_terms=False,
            requires_parabolic_profile=True,
        )
    raise ValueError(f"unknown model descriptor {name!r}")


@dataclass(frozen=True)
class SpatialStrategy:
    descriptor: str
    family: str
    native_scheme: str | None
    degree: int | None = None
    fallback: str | None = None
    tier: str = PUBLICATION_TIER
    scientific_tier: str | None = None

    def metadata(self) -> dict[str, object]:
        return {
            "descriptor": self.descriptor,
            "family": self.family,
            "native_scheme": self.native_scheme,
            "degree": self.degree,
            "fallback": self.fallback,
            "cell_average_update": self.family == "dg",
            "tier": self.tier,
            "scientific_tier": self.scientific_tier or self.tier,
        }


def spatial_strategy(name: str) -> SpatialStrategy:
    normalized = normalize_name(name)
    if normalized == "fv-first-order":
        return SpatialStrategy(normalized, "fvm", "first-order")
    if normalized == "fv-muscl":
        return SpatialStrategy(normalized, "fvm", "muscl")
    if normalized == "fv-lax-wendroff":
        return SpatialStrategy(normalized, "fvm", "lax-wendroff")
    if normalized in {"dg-p0", "dg-p1", "dg-p2"}:
        degree = int(normalized[-1])
        scheme = "first-order" if degree == 0 else "muscl"
        return SpatialStrategy(
            normalized,
            "dg",
            scheme,
            degree=degree,
            fallback="cell-average-fv-update",
            tier=EXPERIMENTAL_SMOKE_TIER,
            scientific_tier=JULIA_REFERENCE_ONLY_TIER,
        )
    if normalized == "fem-stationary-stokes":
        return SpatialStrategy(normalized, "fem", None)
    raise ValueError(f"unknown spatial descriptor {name!r}")


@dataclass(frozen=True)
class TimeStepperStrategy:
    descriptor: str

    def step(self, area: np.ndarray, flow: np.ndarray, dt: float, t: float, rhs: Rhs) -> ArrayPair:
        if self.descriptor == "euler":
            da, dq = rhs(area, flow, t, dt)
            return area + dt * da, flow + dt * dq
        if self.descriptor == "ssprk2":
            k1a, k1q = rhs(area, flow, t, dt)
            a1, q1 = area + dt * k1a, flow + dt * k1q
            k2a, k2q = rhs(a1, q1, t + dt, dt)
            return 0.5 * area + 0.5 * (a1 + dt * k2a), 0.5 * flow + 0.5 * (q1 + dt * k2q)
        if self.descriptor == "ssprk3":
            k1a, k1q = rhs(area, flow, t, dt)
            a1, q1 = area + dt * k1a, flow + dt * k1q
            k2a, k2q = rhs(a1, q1, t + dt, dt)
            a2, q2 = 0.75 * area + 0.25 * (a1 + dt * k2a), 0.75 * flow + 0.25 * (q1 + dt * k2q)
            k3a, k3q = rhs(a2, q2, t + 0.5 * dt, dt)
            return (area + 2.0 * (a2 + dt * k3a)) / 3.0, (flow + 2.0 * (q2 + dt * k3q)) / 3.0
        raise ValueError(f"unknown time stepper {self.descriptor!r}")


def time_stepper_strategy(name: str) -> TimeStepperStrategy:
    normalized = normalize_name(name)
    if normalized in {"euler", "ssprk2", "ssprk3"}:
        return TimeStepperStrategy(normalized)
    raise ValueError(f"unknown time stepper {name!r}")


@dataclass(frozen=True)
class RheologyStrategy:
    descriptor: str
    eta0: float = 0.56
    eta_inf: float = 0.0345
    lambda_s: float = 3.313
    yasuda_a: float = 2.0
    flow_index: float = 0.3568
    yield_stress: float = 0.04
    plastic_viscosity: float = 0.035
    consistency: float = 0.035
    shear_floor: float = 1.0e-8

    def dynamic_viscosity(self, shear_rate: float, newtonian_nu: float, rho: float) -> float:
        gamma = max(abs(float(shear_rate)), self.shear_floor)
        if self.descriptor == "newtonian":
            return rho * newtonian_nu
        if self.descriptor == "carreau":
            return self.eta_inf + (self.eta0 - self.eta_inf) * (1.0 + (self.lambda_s * gamma) ** 2.0) ** (
                (self.flow_index - 1.0) / 2.0
            )
        if self.descriptor == "carreau-yasuda":
            return self.eta_inf + (self.eta0 - self.eta_inf) * (1.0 + (self.lambda_s * gamma) ** self.yasuda_a) ** (
                (self.flow_index - 1.0) / self.yasuda_a
            )
        if self.descriptor == "casson":
            return (math.sqrt(self.yield_stress / gamma) + math.sqrt(self.plastic_viscosity)) ** 2
        if self.descriptor == "power-law":
            return self.consistency * gamma ** (self.flow_index - 1.0)
        raise ValueError(f"unknown rheology {self.descriptor!r}")

    def metadata(self) -> dict[str, object]:
        return {"descriptor": self.descriptor}


def rheology_strategy(name: str) -> RheologyStrategy:
    normalized = normalize_name(name)
    if normalized in {"newtonian", "carreau", "carreau-yasuda", "casson", "power-law"}:
        return RheologyStrategy(normalized)
    raise ValueError(f"unknown rheology {name!r}")


@dataclass(frozen=True)
class VelocityProfileStrategy:
    descriptor: str
    exponent: float | None = None
    shear_rate_factor: float = 4.0
    source_alpha: float | None = None

    @property
    def momentum_alpha(self) -> float:
        if self.descriptor == "flat":
            return 1.0
        if self.descriptor == "parabolic":
            return 4.0 / 3.0
        assert self.exponent is not None
        return (self.exponent + 2.0) / (self.exponent + 1.0)

    @property
    def mean_to_max_ratio(self) -> float:
        if self.descriptor == "flat":
            return 1.0
        if self.descriptor == "parabolic":
            return 0.5
        assert self.exponent is not None
        return self.exponent / (self.exponent + 2.0)

    @property
    def gamma_plus_two(self) -> float:
        if self.descriptor == "flat":
            return self.shear_rate_factor
        if self.descriptor == "parabolic":
            return 4.0
        assert self.exponent is not None
        return self.exponent + 2.0

    def metadata(self) -> dict[str, object]:
        return {
            "descriptor": self.descriptor,
            "exponent": self.exponent,
            "alpha": self.momentum_alpha,
            "source_alpha": self.source_alpha,
            "shear_rate_factor": self.gamma_plus_two,
        }


def velocity_profile_strategy(
    name: str,
    *,
    exponent: float | None = None,
    alpha: float | None = None,
    shear_rate_factor: float = 4.0,
) -> VelocityProfileStrategy:
    if alpha is not None:
        if not 1.0 < alpha < 2.0:
            raise ValueError("--alpha must satisfy 1 < alpha < 2")
        name = "power"
        exponent = (2.0 - alpha) / (alpha - 1.0)
    normalized = normalize_name(name)
    if normalized == "flat":
        if shear_rate_factor <= 0.0:
            raise ValueError("flat profile shear factor must be positive")
        return VelocityProfileStrategy(normalized, shear_rate_factor=shear_rate_factor)
    if normalized == "parabolic":
        return VelocityProfileStrategy(normalized)
    if normalized == "power":
        if exponent is None or exponent <= 0.0:
            raise ValueError("power velocity profile requires positive --profile-exponent or --alpha")
        return VelocityProfileStrategy(normalized, exponent=float(exponent), source_alpha=alpha)
    raise ValueError(f"unknown velocity profile {name!r}")


@dataclass(frozen=True)
class InletBoundaryStrategy:
    descriptor: str
    umax: float = 45.0
    waveform_path: str | None = None

    def waveform(self) -> tuple[np.ndarray, np.ndarray] | None:
        if self.waveform_path is None:
            return None
        data = np.loadtxt(self.waveform_path, dtype=float)
        values = np.atleast_2d(data)
        if values.shape[1] != 2:
            flat = values.reshape(-1)
            if flat.size % 2:
                raise ValueError("flow waveform file must contain time/flow pairs")
            values = flat.reshape((-1, 2))
        times = values[:, 0]
        flows = values[:, 1]
        if times.size < 2 or abs(times[0]) > 1.0e-12 or not np.all(np.diff(times) > 0.0):
            raise ValueError("flow waveform times must start at 0 and be strictly increasing")
        return times, flows

    def metadata(self) -> dict[str, object]:
        return {"descriptor": self.descriptor, "umax": self.umax, "waveform_path": self.waveform_path}


def inlet_boundary_strategy(
    name: str, *, umax: float = 45.0, waveform_path: str | None = None
) -> InletBoundaryStrategy:
    normalized = normalize_name(name)
    if normalized == "steady-velocity":
        if umax < 0.0:
            raise ValueError("--inlet-umax must be nonnegative")
        return InletBoundaryStrategy(normalized, umax=umax)
    if normalized == "flow-waveform":
        if waveform_path is None:
            raise ValueError("--flow-waveform is required with --inlet flow-waveform")
        path = Path(waveform_path).expanduser()
        if not path.is_file():
            raise ValueError(f"flow waveform file not found: {waveform_path}")
        strategy = InletBoundaryStrategy(normalized, waveform_path=str(path))
        strategy.waveform()
        return strategy
    raise ValueError(f"unknown inlet boundary {name!r}")


@dataclass(frozen=True)
class OutletBoundaryStrategy:
    descriptor: str
    reflection_coefficient: float = 0.0
    reference_flow: float = 0.0

    def metadata(self) -> dict[str, object]:
        return {
            "descriptor": self.descriptor,
            "reflection_coefficient": self.reflection_coefficient,
            "reference_flow": self.reference_flow,
        }


def outlet_boundary_strategy(
    name: str,
    *,
    reflection_coefficient: float = 0.0,
    reference_flow: float = 0.0,
) -> OutletBoundaryStrategy:
    normalized = normalize_name(name)
    if normalized == "fixed-area-characteristic":
        return OutletBoundaryStrategy(normalized)
    if normalized == "reflection-coefficient":
        if not -1.0 <= reflection_coefficient <= 1.0:
            raise ValueError("--reflection-coefficient must be in [-1, 1]")
        if not math.isfinite(reference_flow):
            raise ValueError("--reference-flow must be finite")
        return OutletBoundaryStrategy(normalized, reflection_coefficient, reference_flow)
    raise ValueError(f"unknown outlet boundary {name!r}")
