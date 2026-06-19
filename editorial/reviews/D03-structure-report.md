# D03 Structure Report

## Scope

- Dispatch: D03-STRUCTURE
- Role: Structural Editor
- Manuscript source mode: read-only
- Source commit: `371ba631f7cb24a3463e4923696218304bc6ff09`
- Baseline PDF: `editorial/baseline/final-report-baseline.pdf`

## Assignment Basis

The plan assigns every current top-level numbered `\section` entry in `final-report.toc`: Sections 1-7 and Appendices A-H. Numbered subsections remain dependencies inside their parent section because the requested structural decisions and page targets are chapter/appendix-level.

## Structural Decisions

- Section 1 is rewritten so the research problem, questions, contributions, and limits appear within the first approximately four main-text pages.
- Clinical pressure/FFR motivation is reduced to one compact paragraph.
- Current Figures 2 and 3 are deleted unless a retained result directly uses them.
- Material derivative, Reynolds transport, continuum balance derivations, Clay-problem discussion, and generic cylindrical Navier-Stokes detail leave the main narrative.
- Section 3 becomes the authoritative implementation contract.
- Section 4 foregrounds MMS and the geometry-rest failure.
- Section 5 is retitled and framed as a diagnostic 1D-3D velocity comparison using discrepancy terminology.
- Sections 6 and 7 answer the three research questions directly.
- Appendices D-F are deleted unless a later approved edit moves a small required definition to Appendix B or C.
- Appendix H becomes a concise code-availability and canonical-release statement.

## Page Plan

| Unit | Current pages | Action | Target |
|---|---:|---|---:|
| Introduction | 5-19 | rewrite | 5-6 |
| Focused literature | 20-24 | compress | 5-6 |
| Methodology | 25-36 | rewrite | 10-12 |
| Verification and audit | 37-45 | rewrite | 8-10 |
| Diagnostic comparison | 46-50 | rewrite | 6-8 |
| Discussion | 51-52 | rewrite | 4-5 |
| Conclusion | 53-54 | rewrite | 2-3 |

Projected main-text length is 40-50 pages before references.

## Risks

- Highest-risk structural work is in Sections 1, 3, 4, 5, and Appendix G because those units carry equations, numerical anchors, terminology constraints, or generated tables.
- Section 5 depends on resolving or explicitly carrying the D02 radial-profile numerical conflict.
- Section 4 depends on preserving the rest-state peak and `t=1 s` evidence without softening the non-well-balanced result.
- Appendix H cannot be finalized until the release gate supplies one canonical integrated commit or tag.

## Outputs

- `editorial/section_plan.yaml`
- `editorial/reviews/D03-structure-report.md`

STATUS: PASS
UNASSIGNED SECTIONS: 0
STRUCTURAL BLOCKERS: 0
PROJECTED MAIN-TEXT PAGES: 40-50
