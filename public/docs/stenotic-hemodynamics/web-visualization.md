# StenoticHemodynamics Web Visualization

The browser visualization layer is a static review surface for native
resolved-FSI and supplied resolved-3D bundles. It has two pieces:

- Julia export command: `visualization export-web`
- Browser viewer: `packages/stenotic-hemodynamics-viewer/`

The viewer is TypeScript, React, Vite, MUI, and Three.js. It reads only static
files: `manifest.json`, binary geometry, binary fields, and optional JSON
sidecars. It does not require or expose a backend API.

## Artifact Contract

Schema v1 is the retained single-frame format. It stores shared geometry under
`geometry/`, one frame under `snapshots/t000/`, top-level `fields`, and a
single snapshot record. Use it for direct `--velocity-xdmf` smoke exports.

Schema v2 is the temporal production-review format. It stores shared geometry
once under `geometry/`, writes per-frame fields under `snapshots/t0000/`,
`snapshots/t0001/`, and so on, and records:

- `schema_version = 2`
- `snapshot_count`
- `time_axis` with `frame_id`, `time_s`, and `delta_t_s`
- `available_fields`
- per-snapshot `fields` asset descriptors
- per-frame `ranges`
- top-level `global_ranges`
- `skipped_snapshots`
- `estimated_playback_fps`

Both schemas preserve the same claim boundary:

```text
native resolved-FSI artifact/operator evidence only; not paper-grade native resolved-FSI Section 4.1 reproduction
```

Both schemas also record coordinate semantics. The default
`coordinate_mode=reference` means `geometry/reference_positions.f32` stores the
reference mesh and the viewer may add displacement for deformed display.
`coordinate_mode=deformed` means positions are already deformed; the viewer
must not apply displacement a second time.

The viewer normalizes v1 manifests into a one-frame timeline. Temporal controls
are shown only when `snapshot_count > 1` or more than one snapshot record is
present.

The field rail is backed by the loaded manifest and active snapshot. It toggles
the scalar visualization between velocity magnitude, pressure, and displacement
magnitude. Pressure and displacement are disabled when the manifest or current
snapshot does not provide the corresponding field assets. The colorbar reports
the active field label, units, min/max ticks, and both current-frame and global
ranges when those ranges are present.

The diagnostics drawer surfaces manifest evidence badges for the claim
boundary, coordinate mode, result class, skipped snapshots, sidecars, and
observations when those records are present. Sidecars and observation artifacts
are displayed as provenance/operator evidence only. Loaded discrepancy or
observation summaries are not validation or parity claims by themselves.

The diagnostics drawer includes a viewer-derived surface slice panel. It
samples nodes referenced by the surface triangles, chooses the longest displayed
geometry axis, bins those samples into slices, and reports radius bars plus
slice-level mean speed and pressure summaries. For
`coordinate_mode=reference`, the panel uses the same single displacement
application as the scene when deformed display is active. For
`coordinate_mode=deformed`, it uses the loaded positions without adding
displacement again. The panel is an inspection/operator aid; it is not
production validation or paper-grade reproduction evidence.

## Single-Frame Smoke Export

Use direct XDMF/HDF5 inputs for a v1 smoke export:

```bash
pipenv run ops-experiment visualization export-web \
  --velocity-xdmf public/var/data/simulations/canic_case3/50/velocity.xdmf \
  --pressure-xdmf public/var/data/simulations/canic_case3/50/pressure.xdmf \
  --displacement-xdmf public/var/data/simulations/canic_case3/50/displace.xdmf \
  --case-id sev50 \
  --target-time 1.4995 \
  --schema-version 1 \
  --output-dir tmp/simulations/output/visualization/canic_case3 \
  --overwrite
```

If `--schema-version` is omitted in direct mode, the exporter defaults to v1.

## Production Multi-Snapshot Export

Use production snapshot output directories for a v2 temporal export:

```bash
pipenv run ops-experiment visualization export-web \
  --input-production-dir tmp/simulations/output/native-resolved-fsi-production/sev23 \
  --case-id sev23 \
  --snapshot-stride 1 \
  --max-snapshots 24 \
  --output-dir tmp/simulations/output/visualization/sev23 \
  --overwrite
```

In production-directory mode, the exporter discovers snapshots in this order:

1. `restart_metadata.json` / `snapshot_outputs`
2. `snapshot_manifest.csv`
3. `snapshot-t*` child directories
4. the input directory itself as a direct single-bundle fallback

Selectors are applied after discovery:

```bash
pipenv run ops-experiment visualization export-web \
  --input-production-dir tmp/simulations/output/native-resolved-fsi-production/sev23 \
  --case-id sev23 \
  --snapshot-include snapshot-t0p0001,snapshot-t0p0002 \
  --snapshot-exclude snapshot-t0p0001 \
  --snapshot-stride 2 \
  --output-dir tmp/simulations/output/visualization/sev23-selected \
  --overwrite
```

If `--schema-version` is omitted in production-directory mode, the exporter
defaults to v2.

## Static Hosting

For local viewer development:

```bash
cd packages/stenotic-hemodynamics-viewer
npm install
npm run generate-demo
npm run validate-demo
npm run typecheck
npm run build
npm run test:browser
npm run dev
```

The bundled demo loads at:

```text
http://localhost:5173/
```

Load another static export with a manifest query parameter:

```text
http://localhost:5173/?manifest=/data/my-case/manifest.json
```

To build and serve the production viewer instead of the dev server:

```bash
cd packages/stenotic-hemodynamics-viewer
npm run serve

# or from the repository root
pipenv run ops-serve-stenotic-hemodynamics-viewer
```

The `serve` command rebuilds before starting Vite's preview server.

The built preview uses Vite's preview server, which defaults to:

```text
http://localhost:4173/
```

For URL paths with spaces or special characters, URL-encode the `manifest`
value. The app resolves relative manifest values against the current page URL,
so static site hosting can serve the viewer and exported data from the same
directory tree.

## Scratch Policy

Generated visualization exports should stay under ignored scratch paths by
default:

```text
tmp/simulations/output/visualization/<case>/
```

Only curated demo fixtures should be copied into:

```text
packages/stenotic-hemodynamics-viewer/public/data/demo/
```

Do not refresh `public/final-report.pdf` or report-consumed figure assets for
viewer work unless an explicit publication/artifact-refresh lane includes that
scope.

## Validation Recipe

For an exported production directory:

```bash
pipenv run ops-experiment visualization export-web \
  --input-production-dir tmp/simulations/output/native-resolved-fsi-production/sev23 \
  --case-id sev23 \
  --output-dir tmp/simulations/output/visualization/sev23 \
  --overwrite

node -e 'const fs=require("fs"); const m=JSON.parse(fs.readFileSync("tmp/simulations/output/visualization/sev23/manifest.json","utf8")); console.log({schema_version:m.schema_version,snapshot_count:m.snapshot_count ?? m.snapshots.length,asset_root:"tmp/simulations/output/visualization/sev23"});'
du -sh tmp/simulations/output/visualization/sev23

cd packages/stenotic-hemodynamics-viewer
npm run typecheck
npm run build
npm run validate-demo
npm run test:browser
```

Focused Julia validation for the exporter:

```bash
packages/stenotic-hemodynamics/bin/julia-release --project=packages/stenotic-hemodynamics -e 'using Test, SHA, HDF5, StenoticHemodynamics; include("packages/stenotic-hemodynamics/test/test_helpers.jl"); include("packages/stenotic-hemodynamics/test/test_native_resolved_fsi_visualization.jl")'
```
