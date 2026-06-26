# Manuscript Claim Register

The claim register at `public/reproducibility/manuscript-claim-register.tsv`
is a reader-facing trace map for the main manuscript claims. Use it to see
which manuscript locations depend on which sources, what each source is being
asked to support, and where the claim boundary should stay narrow during
advisor review.

The register supports claim tracing. It is not, by itself, a citation audit,
a source-quality audit, or a proof that the manuscript claims are valid.
Advisor review should still inspect the manuscript prose, cited sources, and
the relevant verification or validation evidence before promoting any claim.

## Columns

| Column | Meaning |
| --- | --- |
| `location` | Manuscript file or files where the claim is active. Multiple locations mean the same bounded claim is used in more than one section. |
| `claim_text` | The bounded manuscript claim to check. Treat this as a review paraphrase, not a replacement for the final prose. |
| `bib_key` | Bibliography key for the cited source or reference record. |
| `source_role` | Why the source is in the register, such as theory, benchmark, clinical context, software/reproducibility, or model-comparison support. |
| `evidence_type` | The kind of evidence being invoked: derivation, review, experiment, sensitivity study, benchmark, standard, software record, or related category. |
| `scope_or_population` | The population, model class, geometry family, benchmark setting, or other domain where the source evidence applies. |
| `observable` | The quantity or concept the source actually supports, such as pressure, flow, FFR-style pressure ratio, WSS, benchmark states, or reproducibility workflow outputs. |
| `direct_or_inferred` | Whether the claim is directly supported by the source or inferred from the source under an additional manuscript argument. |
| `source_status` | Source type or publication status, for example peer-reviewed article, review, standard, book, official project page, or preprint. |
| `revision_status` | Current manuscript-review status and the sections where the claim remains active. |

## Advisor review priorities

The most important rows to review are the categories that control the
manuscript's evidence boundaries:

- **Model-reduction and model-contract claims**: section averaging, 0D/1D/3D
  hierarchy, multiscale coupling, and dimensional-tier language. These rows
  prevent the manuscript from implying that a reduced model is justified by
  dimensional tier alone.
- **Observable and diagnostic-boundary claims**: FFR, pressure ratios, WSS
  definitions, pressure-flow interpretation, and anatomy-versus-function
  distinctions. These rows are central because a model claim should name the
  observable it can actually support.
- **Stenosis mechanism and case-study claims**: idealized stenosis experiments,
  the Canic et al. preprint, and patient-specific or geometry/rheology
  sensitivity studies. These rows mark where the manuscript must avoid
  over-reading controlled or preprint evidence as clinical validation.
- **Verification, validation, benchmark, and reproducibility claims**:
  VVUQ terminology, Boileau/openBF/SimVascular references, and shared model
  repositories. These rows distinguish numerical comparison and workflow
  reproducibility from validation of a hemodynamic prediction.
- **Learned-model and operator claims**: PCNDE and multifidelity operator rows.
  These rows should stay tied to their dataset, geometry family, input space,
  and derived observables rather than being promoted to broad model equivalence.

## Intended use

During review, filter by `location` to inspect a section, then read
`claim_text`, `scope_or_population`, and `observable` together before checking
the source. A row should be treated as acceptable only when the manuscript prose
keeps the same boundary as the source evidence. If the prose makes a stronger
statement than the row, either narrow the prose or add separate evidence and a
new row.
