# Next-Round Release Provenance and Asset Stewardship Plan

## Status

Implemented for the local committee-submission release-provenance round after
commit `e40e55e` (`Update raw input release manifest`).

The manuscript and public PDF have already passed the committee-facing prose
closeout. The next round should not reopen broad prose editing. Its job is to
make the repository handoff and release provenance internally consistent:
release manifest fields, raw-input policy, consumed-report asset inventory, and
validation commands.

## Editorial Critique

The current asset architecture is sensible:

- `public/var/data/simulations/**` is ignored local raw-input storage for
  optional XDMF/HDF5 resolved-3D fields.
- `report/assets/**` holds tracked derived report assets that TeX can consume.
- `/tmp/masters-report-build/report-build-summary.json` is the report-build
  authority for files actually consumed by the compiled PDF.
- `public/reproducibility/release-manifest.json` is release/provenance metadata,
  not a TeX-consumption inventory.

The remaining release hygiene items for this round were the manifest status,
explicit final PDF hash metadata, and a documented scratch-only checksum audit
for optional raw inputs. Those were repository-handoff risks, not thesis-claim
risks.

## Round Result

- `public/reproducibility/release-manifest.json` now records
  `committee_submission_ready`, the validation-only build command, the current
  `public/final-report.pdf` SHA-256, non-self-referential source/PDF commit
  pointers, and the scratch-only raw-input checksum audit convention.
- Local raw-input audits were generated only under `/tmp`:
  `/tmp/raw-3d-inputs-files.txt` and `/tmp/raw-3d-inputs-sha256.txt`.
- The report build summary remains the authority for TeX-consumed inputs.
- `public/final-report.pdf` was not refreshed in this round.

## Objective

Produce a release-ready provenance bundle without changing mathematical claims,
generated report assets, raw resolved-3D inputs, package code, or the public PDF
unless validation proves a source/PDF refresh is necessary.

## Files in Scope

Primary:

- `public/reproducibility/release-manifest.json`
- `public/docs/resolved3d-workflows.md`
- `public/docs/report-assets-and-provenance.md`
- `public/docs/publication-readiness.md`
- `report/TODO.md`

Conditional:

- `report/appendices/code-and-ai-use.tex` only if Appendix H has drifted from
  the manifest or workflow docs.
- `public/final-report.pdf` only if a scoped report source change requires a
  synced PDF refresh.

Out of scope:

- `public/var/data/simulations/**`
- `tmp/simulations/output/**`
- `packages/stenotic-hemodynamics/**`
- bibliography/source-inventory rows
- numerical values, tables, figures, and claim-register rows

## Implementation Plan

### Step 1 - Re-Anchor the Live Tree

Run:

```sh
git status --short
git log --oneline -5
pipenv run ops-orchestrate status --json
```

Confirm whether any dirty files are unrelated to release/provenance work. Do
not stage unrelated package/runtime changes.

### Step 2 - Verify Current Report and PDF State

Run:

```sh
pipenv run ops-audit-references
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
shasum -a 256 public/final-report.pdf
jq -r '.synced_pdf.sha256 // empty' /tmp/masters-report-build/report-build-summary.json
```

Interpretation:

- If the scratch build passes and no TeX source changed, do not refresh
  `public/final-report.pdf`.
- If the PDF hash differs only because the scratch build was validation-only,
  record both hashes and avoid artifact churn.
- If report source must change, run the synced build only after the source patch
  passes validation.

### Step 3 - Seal Release Manifest Metadata

Edit `public/reproducibility/release-manifest.json`.

Required changes:

- Replace `status: pending_final_release` with a release-candidate status such
  as `committee_submission_ready` or `release_candidate`.
- Replace `release_tag: pending_final_release` with the intended local release
  tag if known. If no tag is being created in this lane, use
  `not_declared_for_this_local_copy`.
- Replace `final_integrated_commit: pending_final_release` with a non-self-
  referential policy. Prefer explicit fields such as:
  - `report_source_commit`
  - `pdf_artifact_commit`
  - `manifest_commit_policy`
- Add `final_pdf` metadata:
  - path: `public/final-report.pdf`
  - SHA-256 from `shasum -a 256 public/final-report.pdf`
  - generation command from the report build wrapper
- Keep `public_repository_url` and `archival_doi` as `not_declared` unless the
  user explicitly provides a public URL or DOI.
- Preserve the raw-input convention added in `e40e55e`: cases `77` and `60`
  require velocity, pressure, and displacement companions; case `50` remains
  supplemental local scratch evidence.

Do not attempt to make the manifest commit hash self-referential. If a release
tag is created later, the tag itself is the stable pointer to the manifest
state.

### Step 4 - Generate a Local Raw-Input Checksum Audit

Generate a scratch-only audit:

```sh
find public/var/data/simulations/canic_case3 -type f -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 \
  > /tmp/raw-3d-inputs-sha256.txt

find public/var/data/simulations/canic_case3 -type f -print | sort \
  > /tmp/raw-3d-inputs-files.txt

du -sh public/var/data public/var/data/simulations/canic_case3/*
wc -l /tmp/raw-3d-inputs-files.txt /tmp/raw-3d-inputs-sha256.txt
```

Keep this audit in `/tmp` unless the user explicitly approves committing a
tracked checksum manifest for local raw inputs. The raw files themselves remain
ignored and must not be staged.

### Step 5 - Reconcile Workflow Documentation

Review these files against the release manifest:

```sh
rg -n "public/var/data|velocity|pressure|displace|coordinate-mode|release-manifest|final-report.pdf" \
  public/docs/resolved3d-workflows.md \
  public/docs/report-assets-and-provenance.md \
  public/docs/publication-readiness.md \
  report/appendices/code-and-ai-use.tex
```

Patch only real drift:

- The docs should say raw XDMF/HDF5 inputs are ignored local optional inputs.
- The docs should say report assets are derived and tracked only when consumed.
- The docs should mention both reference-coordinate and deformed-coordinate
  comparison asset refreshes when discussing retained comparison assets.
- Appendix H should remain a thesis-facing provenance summary, not a full data
  management manual.

### Step 6 - Refresh the Consumed-Asset Inventory

After the validation build, generate a fresh scratch inventory:

```sh
jq -r '.consumed_inputs[]' /tmp/masters-report-build/report-build-summary.json \
  | sort > /tmp/report-consumed-inputs.txt

find report/assets report/notebooks report/archive -type f \
  | sort > /tmp/report-tree-artifacts.txt

comm -13 /tmp/report-consumed-inputs.txt /tmp/report-tree-artifacts.txt \
  > /tmp/report-unconsumed-artifacts.txt

wc -l /tmp/report-consumed-inputs.txt /tmp/report-tree-artifacts.txt /tmp/report-unconsumed-artifacts.txt
sed -n '1,160p' /tmp/report-unconsumed-artifacts.txt
```

Classify the output in the handback as:

- consumed report assets
- raw/local input provenance
- generated but not currently consumed support assets
- archive/superseded source
- notebook/provenance material

Do not delete or move artifacts in this round unless a file is plainly
accidental and the user explicitly widens the scope.

### Step 7 - Validation Gate

Run:

```sh
jq . public/reproducibility/release-manifest.json >/tmp/release-manifest.pretty.json
git diff --check -- public/reproducibility report/TODO.md public/docs report/appendices/code-and-ai-use.tex
pipenv run ops-audit-references
pipenv run ops-build-report --outdir /tmp/masters-report-build --no-sync-final-pdf
```

If `report/appendices/code-and-ai-use.tex` changes, also run:

```sh
pdftotext -layout /tmp/masters-report-build/final-report.pdf /tmp/final-report-scratch.txt
rg -n "pending_final_release|accepted-reference|validation workflow|regeneration command|Newtonian wall" /tmp/final-report-scratch.txt
```

Expected result:

- JSON parses.
- TeX build passes.
- No new bibliography/source-inventory work is needed.
- No raw XDMF/HDF5 inputs are staged.
- `public/final-report.pdf` is unchanged unless the lane explicitly refreshed
  it after a source change.

### Step 8 - Commit Plan

Use one commit if only provenance/docs/TODO changed:

```sh
git add public/reproducibility/release-manifest.json \
        public/docs/resolved3d-workflows.md \
        public/docs/report-assets-and-provenance.md \
        public/docs/publication-readiness.md \
        report/TODO.md
git commit -m "Finalize release provenance plan"
```

If Appendix H changes, include it in the same commit only when the manifest/docs
patch requires thesis-facing provenance wording:

```sh
git add report/appendices/code-and-ai-use.tex
```

Use a separate PDF commit only if the synced report build is explicitly run:

```sh
git add -f public/final-report.pdf
git commit -m "Refresh final report PDF"
```

## Acceptance Criteria

- Release manifest matches the current raw-input convention.
- The report build summary remains the authority for consumed PDF inputs.
- Raw data remains ignored and unstaged.
- Docs and Appendix H do not contradict each other.
- The next executor can run the commands above without inferring scope.
- Final handback reports any remaining release blockers as provenance blockers,
  not manuscript-prose blockers.
