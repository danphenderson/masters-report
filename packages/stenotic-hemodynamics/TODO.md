# StenoticHemodynamics Next-Round Fleet TODO

Date: 2026-06-23

This is the next supervised dispatch plan for
`packages/stenotic-hemodynamics`. It starts from the current `master` checkout
after the native resolved-FSI cleanup and production-control round. The next
objective is to deepen the native generator beyond smoke-backed independent
snapshots while preserving the importer and parity workflows for externally
generated Matlab/reference bundles.

## Baseline For Next Round

The current local package work has delivered:

- Split native resolved-FSI adapter files:
  - `adapters/native_resolved_fsi_types.jl`
  - `adapters/native_resolved_fsi_gridap.jl`
  - `adapters/native_resolved_fsi_sampling.jl`
  - `adapters/native_resolved_fsi_partitioned.jl`
  - `adapters/native_resolved_fsi_roundtrip.jl`
- Production controls for Section 4.1 native resolved-FSI runs, including
  case, mesh, time, snapshot, Picard, membrane, coupling, and output-volume
  guards.
- A production runner that reuses the current smoke-backed partitioned driver.
- Multi-snapshot production output with existing importer-compatible bundle
  filenames:
  - `velocity.xdmf`
  - `pressure.xdmf`
  - `displace.xdmf`
- Production sidecars:
  - `snapshot_manifest.csv`
  - `snapshot_diagnostics.csv`
  - `restart_metadata.json`
- Partitioned smoke depth now includes per-time-step coupling iteration caps,
  under-relaxation, displacement residual history, and prescribed radial wall
  velocity as Gridap wall Dirichlet data on the deformed geometry.
- Restart-identification metadata that explicitly marks state-carrying resume
  as deferred.
- Section 4.1 observation artifacts and skip-safe production parity plans.
- Separate velocity and pressure operator status seams.
- Public workflow documentation under
  `public/docs/stenotic-hemodynamics/`, with package-local native FSI docs
  reduced to pointer stubs.

Bounded interpretation:

- Native generation still uses independent smoke-backed partitioned solves for
  scheduled snapshots, but each partitioned smoke solve now feeds the current
  reduced wall velocity into the fluid wall boundary. It is not a monolithic
  transient ALE FSI method and does not include ALE mesh-velocity terms.
- The production sidecars improve reproducibility and handoff, but do not yet
  provide state-carrying restart/resume.
- Section 4.1 observation artifacts are operator/parity artifacts. They do not
  prove paper-grade reproduction.
- External resolved-3D import remains first-class. Native generation augments
  the importer; it does not replace imported reference data support.

## Orchestration Rules

- Start with:

  ```bash
  pipenv run ops-orchestrate status --json
  ```

- Treat the live dirty tree as authority.
- Use one writer per disjoint file set. If a worker needs files outside its
  assigned scope, it must stop and request expansion before editing.
- Do not repeat worker validation by default. Review diffs and focused
  handback validation, then run one broader gate only at the round boundary or
  when integration risk justifies it.
- Preserve public CLI commands, existing option names, existing XDMF/HDF5 file
  names, and importer schemas unless a lane explicitly widens scope.
- Native output must remain a three-field bundle: velocity, pressure, and
  displacement.
- Optional external data under `public/var/data/simulations/**` may be absent.
  Parity and report-support workflows must return expected skips rather than
  failing public-clone validation.
- Code lanes own docstrings and comments in their assigned files. Do not
  assume existing docstrings are correct after structural moves.
- Keep production helper namespace tight. Add new qualified internal names only
  when they are intentional API-adjacent seams and update the boundary tests in
  the same lane.

## Step 1: Boundary, Restart, And Production Harness Lanes

### Lane 7A: Wall Boundary Verification Harness

Objective: protect the new prescribed radial wall-velocity Dirichlet path with
direct tests before deeper production runs depend on it.

Owned write scope:

- `src/StenoticHemodynamics/adapters/native_resolved_fsi_gridap.jl`
- `src/StenoticHemodynamics/adapters/native_resolved_fsi_partitioned.jl` only
  if a helper must move out of the local solve closure.
- `test/test_native_resolved_fsi_smoke.jl`

Implementation:

1. Factor the radial wall-velocity boundary construction into a small internal
   helper if that is the cleanest way to test it directly.
2. Test centerline zeroing, axial clamping, finite-value rejection, and radial
   direction/sign on representative wall points.
3. Add one tiny partitioned smoke assertion that nonzero wall velocity is
   recorded in the residual history or restart-visible state without requiring
   an expensive production run.
4. Keep the claim boundary explicit: prescribed wall Dirichlet data on deformed
   geometry, not ALE mesh-velocity advection.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_smoke.jl")'
```

Acceptance:

- The wall boundary helper cannot regress to a label-only status without test
  failures.
- Tests remain tiny and deterministic.
- Status strings continue to avoid fixed-wall or monolithic-ALE claims for the
  partitioned prescribed-wall path.

### Lane 7B: Restart Metadata Reader And Resume Contract

Objective: make restart metadata truly reloadable through package-owned code
before attempting state-carrying resume.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- Optional new file:
  `src/StenoticHemodynamics/workflows/native_resolved_fsi_restart.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_public_api.jl` only if a new qualified reader seam is intentional.

Implementation:

1. Add a typed or structured reader for `restart_metadata.json`, using existing
   dependencies or a minimal parser strategy already acceptable in the package.
2. Validate required metadata keys and sidecar paths.
3. Distinguish three states:
   - metadata reloadable
   - state-carrying resume unsupported
   - state-carrying resume implemented
4. Add an explicit resume stub that fails early with a clear message unless
   this lane also implements and tests real resume.
5. Keep the JSON schema backward-compatible with the current 4D sidecar.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl")'
```

Acceptance:

- A tiny production run writes metadata that the package can read back.
- Missing or malformed metadata fails with actionable errors.
- Resume remains explicitly deferred unless a tested resumed run reproduces an
  uninterrupted coarse final bundle.

### Lane 7C: Section 4.1 Production Harness And Dry Run

Objective: give operators a deterministic plan surface for tiny test runs and
deliberate larger Section 4.1 runs without accidental large-output generation.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_workflow_production.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity_production.jl`
- `test/test_native_resolved_fsi_workflow.jl`
- `test/test_native_resolved_fsi_parity.jl`

Implementation:

1. Add dry-run planning for `sev23`, `sev40`, and `sev50` that reports:
   - mesh resolution
   - expected node and tetrahedron counts
   - snapshot schedule
   - raw payload estimate
   - output directories
   - sidecar paths
   - imported-case availability.
2. Add a tiny executable production plan that uses the same production runner
   and parity artifact path as larger cases.
3. Keep high-resolution Section 4.1 execution opt-in through explicit spec
   values and output-volume overrides.
4. Keep `sev50` imported parity as expected-skip until an external bundle is
   wired.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_workflow.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
```

Acceptance:

- Dry-run plans are deterministic for all three Section 4.1 cases.
- Tiny executable production plans write bundles, sidecars, and observation
  artifacts.
- Optional imported bundles are never required for package tests.

## Step 2: Parity, API, And Documentation Lanes

### Lane 7D: Production Observation Artifact Hardening

Objective: turn the current observation CSV artifact into a stable surface for
future report and comparison lanes.

Owned write scope:

- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity.jl`
- `src/StenoticHemodynamics/workflows/native_resolved_fsi_parity_production.jl`
- `test/test_native_resolved_fsi_parity.jl`

Implementation:

1. Add deterministic ordering and explicit row-count summaries for native,
   imported, and parity rows.
2. Add a compact artifact summary sidecar or status object that reports max
   velocity and pressure discrepancies by case/source.
3. Keep velocity and pressure operator statuses separate.
4. Ensure missing imported bundles still write native-only observation rows and
   expected-skip status.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_parity.jl")'
```

Acceptance:

- Observation artifacts are deterministic and summary-ready.
- Native-only, imported-only, and paired parity cases are all covered by tests.
- No optional external data are required.

### Lane 7E: CLI Exposure Decision For Native Production

Objective: decide whether native resolved-FSI production remains qualified
internal or gains a deliberately safe CLI surface.

Owned write scope:

- `test/test_public_api.jl`
- CLI files only if exposing a dry-run or tiny smoke command is intentional.
- `packages/stenotic-hemodynamics/README.md`
- `public/docs/stenotic-hemodynamics/workflows.md`
- `public/docs/julia-cli-workflows.md`

Implementation:

1. Review current qualified internal names and exports.
2. If adding CLI exposure, default to dry-run or tiny smoke settings only.
3. Keep high-resolution production runs behind explicit options and output
   guards.
4. Update docs only for the actual exposed surface.

Validation:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_public_api.jl")'
```

Acceptance:

- Public API tests match the intended boundary.
- Existing public commands remain unchanged.
- No expensive production run can be triggered accidentally from defaults.

### Lane 7F: Native Resolved-FSI Documentation Refresh

Objective: update public docs after the production-control, diagnostics, and
observation artifact lanes without inflating numerical claims.

Owned write scope:

- `public/docs/stenotic-hemodynamics/workflows.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-design.md`
- `public/docs/stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction.md`
- `packages/stenotic-hemodynamics/README.md`
- Package-local pointer stubs only if links change.

Implementation:

1. Document the current tier split:
   - schema workflow
   - fixed-wall smoke
   - partitioned smoke
   - production sidecars
   - observation/parity artifacts
   - deferred coupling/resume/parity claims.
2. Keep external importer support described as retained and supported.
3. Keep Section 4.1 reproduction language bounded to generated artifacts and
   local operator parity evidence.

Validation:

```bash
pipenv run ops-orchestrate docs-contract
git diff --check -- packages/stenotic-hemodynamics/README.md packages/stenotic-hemodynamics/docs public/docs
```

Acceptance:

- Public docs are the authoritative Julia package documentation site.
- Package-local docs remain pointer stubs unless a local contract requires
  otherwise.
- Claims do not exceed implemented solver depth.

## Step 3: Maintenance Lanes

### Lane 7G: Dependency-Boundary Follow-Up

Owned write scope:

- `test/test_extension_contracts.jl`
- One dependency family at a time.

Objective: keep Gridap, HDF5/EzXML, YAML/OpenBF, and SciML import boundaries
documented and tested after the native production additions.

Acceptance:

- Gridap remains confined to native/stokes workflow surfaces that need it.
- HDF5/EzXML remain confined to resolved-3D I/O and writer surfaces.
- SciML and YAML stay lazy where already designed.

### Lane 7H: Scalar Genericity Continuation

Owned write scope:

- One core/numerics family per worker.
- `test/test_scalar_generality.jl`

Objective: continue scalar-generic kernel widening where low risk, while
leaving Gridap-backed native resolved-FSI entrypoints `Float64` until a
dedicated solver-genericity lane exists.

Acceptance:

- New generic tests cover feasible `Float32` or `BigFloat` kernels.
- Remaining `Float64` restrictions are explicit and tested or documented.

## Dispatch Order

1. Start with Lane 7A if the goal is to protect the new prescribed wall
   boundary scientifically before production-depth runs.
2. Run Lane 7B in parallel with 7A only if it stays in restart metadata reader
   code and does not edit adapter solver files.
3. Run Lane 7D in parallel with 7A only if it stays in parity artifact files.
4. Assign Lane 7C after 7A, or after accepting that production remains
   smoke-backed while the boundary harness is still pending.
5. Assign Lane 7E after the API/CLI intent is clear.
6. Assign Lane 7F after the code lanes it documents have landed.
7. Run maintenance lanes 7G and 7H only when their file ownership does not
   overlap active solver-depth work.

Round-boundary gates:

```bash
git diff --check -- packages/stenotic-hemodynamics public/docs
pipenv run ops-orchestrate docs-contract
```

Run `pipenv run ops-julia-check` only at a true integration boundary or when a
cross-surface review finds a real risk not covered by the focused tests.

Commit scope:

- Stage only package/public-doc implementation files assigned in the round.
- Leave unrelated `report/**`, `report/TODO.md`, package `AGENTS.md`, scratch
  outputs, and generated artifacts untouched unless explicitly assigned.
