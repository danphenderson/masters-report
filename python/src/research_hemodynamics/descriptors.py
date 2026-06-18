"""Descriptor registry and factory for the Python CLI."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Iterable

PUBLICATION_TIER = "publication"
EXPERIMENTAL_SMOKE_TIER = "experimental-smoke"
JULIA_REFERENCE_ONLY_TIER = "julia-reference-only"


def normalize_name(value: str) -> str:
    return value.strip().lower().replace("_", "-")


@dataclass(frozen=True)
class Descriptor:
    category: str
    name: str
    description: str
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def key(self) -> tuple[str, str]:
        return self.category, normalize_name(self.name)


class DescriptorRegistry:
    def __init__(self, descriptors: Iterable[Descriptor] = ()) -> None:
        self._items: dict[tuple[str, str], Descriptor] = {}
        for descriptor in descriptors:
            self.register(descriptor)

    def register(self, descriptor: Descriptor) -> None:
        if descriptor.key in self._items:
            raise ValueError(f"duplicate descriptor {descriptor.category}:{descriptor.name}")
        self._items[descriptor.key] = descriptor

    def require(self, category: str, name: str) -> Descriptor:
        key = category, normalize_name(name)
        try:
            return self._items[key]
        except KeyError as exc:
            expected = ", ".join(item.name for item in self.by_category(category))
            raise ValueError(f"unknown {category} descriptor {name!r}; expected one of: {expected}") from exc

    def by_category(self, category: str) -> list[Descriptor]:
        return sorted((item for (cat, _), item in self._items.items() if cat == category), key=lambda item: item.name)

    def categories(self) -> list[str]:
        return sorted({category for category, _ in self._items})

    def as_dict(self) -> dict[str, list[dict[str, Any]]]:
        return {
            category: [
                {"name": item.name, "description": item.description, "metadata": item.metadata}
                for item in self.by_category(category)
            ]
            for category in self.categories()
        }


def d(category: str, name: str, description: str, **metadata: Any) -> Descriptor:
    return Descriptor(category, name, description, metadata)


registry = DescriptorRegistry(
    [
        d(
            "model",
            "canic-extended-1d",
            "Canic extended 1D stenosis model with variable-radius correction terms.",
            wall="elastic1d",
            wall_boundary_condition="reduced-elastic-wall-law",
            variable_radius_terms=True,
            tier=PUBLICATION_TIER,
        ),
        d(
            "model",
            "classical-1d-no-slip",
            "Classical parabolic-profile 1D baseline with wall no-slip antecedent and no Canic variable-radius correction.",
            wall="elastic1d",
            wall_boundary_condition="no-slip-on-wall-Gamma_w-not-inlet-or-outlet",
            variable_radius_terms=False,
            requires_parabolic_profile=True,
            tier=PUBLICATION_TIER,
        ),
        d(
            "spatial",
            "fv-first-order",
            "Publication-tier first-order finite-volume Rusanov method.",
            family="fvm",
            order=1,
            tier=PUBLICATION_TIER,
        ),
        d(
            "spatial",
            "fv-muscl",
            "Publication-tier MUSCL finite-volume method with minmod limiting.",
            family="fvm",
            order=2,
            tier=PUBLICATION_TIER,
        ),
        d(
            "spatial",
            "fv-lax-wendroff",
            "Publication-tier Richtmyer/Lax-Wendroff finite-volume method with minmod interface reconstruction.",
            family="fvm",
            order=2,
            tier=PUBLICATION_TIER,
        ),
        d(
            "spatial",
            "dg-p0",
            "Experimental-smoke DG degree-0 descriptor using a cell-average FV update.",
            family="dg",
            degree=0,
            fallback="cell-average-fv-update",
            tier=EXPERIMENTAL_SMOKE_TIER,
            scientific_tier=JULIA_REFERENCE_ONLY_TIER,
        ),
        d(
            "spatial",
            "dg-p1",
            "Experimental-smoke DG degree-1 descriptor using a cell-average FV update.",
            family="dg",
            degree=1,
            fallback="cell-average-fv-update",
            tier=EXPERIMENTAL_SMOKE_TIER,
            scientific_tier=JULIA_REFERENCE_ONLY_TIER,
        ),
        d(
            "spatial",
            "dg-p2",
            "Experimental-smoke DG degree-2 descriptor using a cell-average FV update.",
            family="dg",
            degree=2,
            fallback="cell-average-fv-update",
            tier=EXPERIMENTAL_SMOKE_TIER,
            scientific_tier=JULIA_REFERENCE_ONLY_TIER,
        ),
        d(
            "spatial",
            "fem-stationary-stokes",
            "Publication-tier deterministic CPU stationary-Stokes projection/initializer, not transient FEM.",
            family="fem",
            tier=PUBLICATION_TIER,
        ),
        d("limiter", "minmod", "TVD minmod limiter."),
        d("time-stepper", "euler", "Forward Euler stepper."),
        d("time-stepper", "ssprk2", "Second-order SSP Runge-Kutta stepper."),
        d("time-stepper", "ssprk3", "Third-order SSP Runge-Kutta stepper."),
        d("backend", "native", "Native NumPy backend."),
        d("backend", "torch", "Torch tensor backend."),
        d("backend", "scipy", "SciPy solve_ivp adapter."),
        d("backend", "sciml-reference", "External Julia/SciML reference adapter."),
        d("scipy-method", "RK45", "SciPy RK45."),
        d("scipy-method", "DOP853", "SciPy DOP853."),
        d("scipy-method", "Radau", "SciPy Radau."),
        d("scipy-method", "BDF", "SciPy BDF."),
        d("scipy-method", "LSODA", "SciPy LSODA."),
        d("sciml-label", "auto", "SciML automatic policy."),
        d("sciml-label", "tsit5", "SciML Tsit5 policy."),
        d("sciml-label", "rodas5p", "SciML Rodas5P policy."),
        d("sciml-label", "ssprk", "Native SSPRK policy label."),
        d("rheology", "newtonian", "Constant-viscosity closure."),
        d("rheology", "carreau", "Carreau closure."),
        d("rheology", "carreau-yasuda", "Carreau-Yasuda closure."),
        d("rheology", "casson", "Casson closure."),
        d("rheology", "power-law", "Power-law closure."),
        d("velocity-profile", "flat", "Flat profile."),
        d("velocity-profile", "parabolic", "Parabolic profile."),
        d("velocity-profile", "power", "Power-family profile."),
        d("initial-condition", "geometry-rest", "Geometry-at-rest initial state."),
        d("initial-condition", "stationary-stokes", "Stationary-Stokes projection initial state."),
        d("inlet-boundary", "steady-velocity", "Steady maximum-velocity inlet."),
        d("inlet-boundary", "flow-waveform", "Periodic volumetric-flow waveform inlet."),
        d("outlet-boundary", "fixed-area-characteristic", "Fixed-area characteristic outlet."),
        d("outlet-boundary", "reflection-coefficient", "Reflection-coefficient outlet."),
    ]
)


class DescriptorFactory:
    def __init__(self, descriptor_registry: DescriptorRegistry = registry) -> None:
        self.registry = descriptor_registry

    def spatial(self, name: str):
        self.registry.require("spatial", name)
        from .strategies import spatial_strategy

        return spatial_strategy(name)

    def time_stepper(self, name: str):
        self.registry.require("time-stepper", name)
        from .strategies import time_stepper_strategy

        return time_stepper_strategy(name)

    def forward_model(self, name: str):
        self.registry.require("model", name)
        from .strategies import forward_model_strategy

        return forward_model_strategy(name)

    def rheology(self, name: str):
        self.registry.require("rheology", name)
        from .strategies import rheology_strategy

        return rheology_strategy(name)

    def velocity_profile(self, name: str, **kwargs: Any):
        self.registry.require("velocity-profile", name)
        from .strategies import velocity_profile_strategy

        return velocity_profile_strategy(name, **kwargs)

    def inlet_boundary(self, name: str, **kwargs: Any):
        self.registry.require("inlet-boundary", name)
        from .strategies import inlet_boundary_strategy

        return inlet_boundary_strategy(name, **kwargs)

    def outlet_boundary(self, name: str, **kwargs: Any):
        self.registry.require("outlet-boundary", name)
        from .strategies import outlet_boundary_strategy

        return outlet_boundary_strategy(name, **kwargs)


factory = DescriptorFactory(registry)
