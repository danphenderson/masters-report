# StenoticHemodynamics Viewer

Static browser visualization layer for native resolved-FSI exports from the
Julia `StenoticHemodynamics` package. The app is TypeScript, React, Vite, MUI,
and Three.js. It reads pre-exported files from `public/data/**` or from a
manifest URL passed as a query parameter. There is no backend API.

## Development

Install and build from this directory:

```bash
npm install
npm run generate-demo
npm run validate-demo
npm run typecheck
npm run build
```

Build and serve the production bundle locally:

```bash
npm run serve
# or from the repository root
pipenv run ops-serve-stenotic-hemodynamics-viewer
```

The `serve` command rebuilds before starting Vite's preview server.

For interactive development:

```bash
npm run test:browser
npm run dev
```

The default dev server serves the bundled temporal demo at:

```text
http://localhost:5173/
```

Load another exported case by passing a served manifest path or URL:

```text
http://localhost:5173/?manifest=/data/my-case/manifest.json
```

The built-app preview uses Vite's preview server, which defaults to:

```text
http://localhost:4173/
```

## Viewer Surface

The first screen is the result viewer: a full-bleed 3D scene, a slim case/time
header, a compact mode rail, timeline controls for temporal manifests, and a
small field legend. Advanced controls and provenance live in a temporary MUI
drawer.

Mode presets:

- `Flow`: velocity magnitude with velocity glyphs.
- `Pressure`: pressure field without glyphs.
- `Wall motion`: displacement magnitude with amplified deformation and a
  reference-shape overlay.

Manifest `coordinate_mode=reference` means geometry stores reference
coordinates and the viewer may apply displacement for deformed display.
Manifest `coordinate_mode=deformed` means geometry is already deformed; the
viewer does not add displacement a second time.

Schema v1 manifests are normalized to a one-frame timeline. Schema v2
manifests load shared geometry once, lazy-load the active frame fields, and
prefetch the next frame.

## Artifact Contract

Schema v1 is the retained single-frame format:

```text
manifest.json
geometry/reference_positions.f32
geometry/surface_indices.u32
snapshots/t000/velocity.f32
snapshots/t000/pressure.f32
snapshots/t000/displacement.f32
snapshots/t000/derived.json
```

Schema v2 is the temporal format:

```text
manifest.json
geometry/reference_positions.f32
geometry/surface_indices.u32
snapshots/t0000/velocity.f32
snapshots/t0000/pressure.f32
snapshots/t0000/displacement.f32
snapshots/t0001/...
```

The manifest records byte lengths, SHA-256 hashes, node counts, triangle
counts, units, time-axis metadata, global/per-frame ranges, skipped snapshots,
claim boundaries, coordinate semantics, and optional sidecars. The viewer
validates binary byte lengths, field lengths, and surface-index bounds before
rendering.

## Export Source

Single-frame smoke export:

```bash
pipenv run ops-experiment visualization export-web \
  --velocity-xdmf public/var/data/simulations/canic_case3/50/velocity.xdmf \
  --pressure-xdmf public/var/data/simulations/canic_case3/50/pressure.xdmf \
  --displacement-xdmf public/var/data/simulations/canic_case3/50/displace.xdmf \
  --case-id sev50 \
  --target-time 1.4995 \
  --output-dir tmp/simulations/output/visualization/canic_case3 \
  --overwrite
```

Production multi-snapshot export:

```bash
pipenv run ops-experiment visualization export-web \
  --input-production-dir tmp/simulations/output/native-resolved-fsi-production/sev23 \
  --case-id sev23 \
  --snapshot-stride 1 \
  --max-snapshots 24 \
  --output-dir tmp/simulations/output/visualization/sev23 \
  --overwrite
```

Generated visualization data should normally stay under ignored scratch paths.
Only curated, reviewed demo subsets should be copied into this package's
`public/data/**` tree.

See `../../public/docs/stenotic-hemodynamics/web-visualization.md` for the full
schema, hosting, and validation contract.
