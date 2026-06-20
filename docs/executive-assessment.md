# Executive Assessment

Review of the June 19, 2026 manuscript.

## Verdict

This is now a strong, coherent master's report. It is in accept-after-targeted-revisions territory rather than in need of another structural rewrite. Its central contribution is appropriately framed as a review-led numerical audit, not as clinical validation or proof of predictive accuracy.

The remaining work should be prioritized in this order: first, fix claim language and notation that could misstate what was actually measured; second, decide which additional computations are feasible; third, trim or qualify secondary material that is not yet carrying its evidentiary weight.

## What Is Already Strong

- The manuscript now has a clear intellectual spine. The research questions, two contributions, notation guide, and report organization appear early and make the transition from continuum mechanics to the case study much easier to follow.
- The physical-to-solver mapping is stated before the detailed numerical results, so the reader is better prepared for the later comparisons.
- Table 4's evidence hierarchy is one of the manuscript's strongest features because it keeps manufactured-solution verification, equilibrium preservation, run admissibility, cross-model comparison, and validation from being treated as interchangeable evidence.
- Chapter 7 is now the strongest chapter. The source-to-implementation map, explicit `R_max`-normalized wall law, solver-coordinate formulation, boundary approximation, and principal numerical method are documented with unusual transparency.
- The manuscript is commendably candid about the non-well-balanced method, unmatched three-dimensional metadata, unresolved transient history, and quarantined radial output.
- The method-of-manufactured-solutions study is substantially stronger. It provides an independently audited forcing record, reports all three error norms, and avoids presenting the timestep-insensitivity rows as a temporal-order study.
- The corrected zero-inlet rest experiment is an important improvement. It shows that the defect is localized, grid-decreasing, and not an imposed through-flow, while still acknowledging that it remains significant on the production grid.
- The 1D-3D comparison is much more defensible. The timestamp is matched, the comparison observable is explicitly defined, the static cut-area audit is separated from the dynamic-area question, and the largest discrepancies are localized rather than summarized only through global norms.
- The conclusion now reports the quantitative findings and gives a credible forward plan without overstating the case study as validation.

## Submission Blockers

### 1. Correct solver-coordinate reporting and timestamp wording

**Issue.** The abstract reports the rest defects as values in `cm^3/s`, but the stated quantity is the solver coordinate `q = Q_phys / pi`, not the physical circular-area flow `Q_phys`.

**Why it matters.** Many readers will interpret an unlabeled flow defect as `Q_phys`. The current wording blurs a distinction that the manuscript otherwise works hard to establish.

**Required revision.**

- Rewrite the abstract to say either `final solver-coordinate rest defects max_i |q_i| are ...`
- Or report both representations: `final solver-coordinate defects are 0.0384 and 0.0634 cm^3/s, corresponding to physical-flow scales pi q of approximately 0.121 and 0.199 cm^3/s`
- Replace `exact-time 0.9995 s comparison` with `timestamp-matched 0.9995 s final sample`
- Keep the same `q` versus `Q_phys` distinction in the conclusion and in any standalone table caption

**Suggested abstract sentence.**

> Because the resolved wall, boundary, material, geometry-state, and transient-history records are not fully matched, the reported differences are descriptive cross-model discrepancies rather than validation errors.

**Minimum acceptable fallback.** If space is tight, keep only the solver-coordinate phrasing and the descriptive-discrepancy sentence, but do not leave the current wording in place.

### 2. Separate observed pressure from wall-law pressure

**Issue.** Definition 7.2 defines `p_g` as a cross-sectional mean of the resolved three-dimensional pressure, but later the same symbol is used for the pressure supplied by the reduced pressure-area wall law.

**Why it matters.** Those are not automatically identical. Their identification is a reduction or closure assumption, not a notational convenience.

**Required revision.**

- Use separate notation for the observed cross-sectional pressure and the reduced wall-law pressure
- Add one explicit sentence saying that the 1D model identifies the reduced pressure variable with a cross-sectional pressure representative and does not resolve radial pressure variation

**Suggested notation split.**

> Observed three-dimensional cross-sectional pressure: `pbar_3D,g(z,t) = (1/A) int_{S(z,t)} p_3D,g dS`
>
> Reduced wall-law pressure: `p_W(A,z,t)`

**Minimum acceptable fallback.** At minimum, rename one of the quantities and state plainly that their identification is a model assumption.

### 3. Finalize the reproducibility record and fix command typography

**Issue.** Appendix H is structurally strong, but it still reads as a release template, and the rendered command blocks are not copyable because punctuation is being spaced out in the PDF.

**Why it matters.** The current text signals that the reproducibility section is not finalized, even though the appendix is close to being strong enough for submission.

**Required revision.**

- Replace the placeholder language with the exact Git commit, release tag, immutable repository or archive URL, archival DOI where available, Julia version, operating-system and hardware summary, and SHA-256 manifest location
- If no archival DOI or stable repository URL exists yet, say that directly and provide the strongest concrete substitute now available
- Use a true verbatim, `lstlisting`, or `minted` environment so commands remain copyable in the rendered PDF

**Minimum acceptable fallback.** If the archival surface is not fully ready, provide the exact commit, a frozen archive location, and the checksum manifest location, and remove the template language that reads as draft boilerplate.

### 4. Correct the "near roundoff" statement in the conclusion

**Issue.** The rest-state balance residuals are around `10^-11` to `10^-12`, which supports near-roundoff language. The production area-flux balance values in Table 13 are around `10^-5` and should not be called roundoff without a normalization that justifies that interpretation.

**Why it matters.** The current wording overstates what the production residuals show.

**Required revision.**

- Distinguish the rest-state balance claim from the production-run balance claim
- If the production residual is retained in unnormalized form, describe it as small at the reported scale rather than as roundoff
- If desired, add a normalized production residual instead of relying on the raw number alone

**Suggested conclusion language.**

> The rest-state finite-volume balances close near roundoff. The production runs retain small area-flux balance residuals at the reported scale, positive area, and zero positivity projections.

## Evidence Strengthening If Feasible

### 5. Add a production-output grid-sensitivity study

**Issue.** The principal comparison uses `N = 400`, while the rest-state defect on that same grid is still materially sized relative to the solver-coordinate comparison-flow scale for C23 and C40. The manuscript does not yet show whether the reported 1D-3D discrepancy metrics are stable under refinement.

**Why it matters.** This is the highest-value numerical addition still available because it tests whether the descriptive comparison metrics are dominated by the chosen 1D grid.

**Preferred revision.**

- Run the C23 and C40 comparisons at `N = 200, 400, 800`
- Use the same target time and section planes
- Report, for each grid: mean physical-flow bias, RMS physical-flow discrepancy, mean velocity bias, RMS velocity discrepancy, maximum velocity discrepancy, location of the maximum, and differences between successive 1D solutions

**Fallback if not completed.** State prominently that the comparison values are single-grid descriptors, avoid presenting more than three significant figures, and do not imply grid-stable agreement that has not been checked.

### 6. Validate the plane-cut operator independently

**Issue.** The static cut-area audit is useful, but it does not fully test the velocity interpolation and integration components of the observation operator.

**Why it matters.** A dedicated operator test would separate operator error from the unresolved axial variation in the extracted three-dimensional flow and would materially strengthen the case study's measurement story.

**Preferred revision.**

- Add a constant-field test where the computed section mean equals `c` and `Q = cA`
- Add an affine-field test where the triangle rule integrates the linearly interpolated field exactly over each cut triangle
- Add a plane-location sensitivity test by moving target planes slightly relative to mesh nodes and faces
- Add a mesh-refinement test that isolates the remaining error from the polygonal approximation of the analytic lumen boundary
- Summarize the maximum area, flow, and mean-velocity errors in a compact appendix table

**Fallback if not completed.** At minimum, add the constant-field and affine-field exactness checks and state clearly that dynamic extraction uncertainty remains only partially isolated.

**Editorial note.** Continue excluding the radial results unless their reducer and summary values are reconciled. The current quarantine is the right decision.

### 7. Diagnose or remove unresolved secondary diagnostics

**Issue.** The modal-DG fixed-mesh `p`-sweep does not show meaningful improvement after `p = 1`, and several appendix figures still read as interesting records rather than fully interpreted evidence.

**Why it matters.** Unresolved secondary results can weaken confidence in otherwise strong primary verification if they are presented as demonstrations without a clear interpretation.

**Preferred revision.**

- Either diagnose the fixed-mesh `p`-sweep plateau and explain it explicitly, or remove that sweep from the manuscript
- Apply the same standard to the other appendix diagnostics:
  - Figure 7 should identify the pressure quantity as a legacy local-denominator diagnostic if it is kept
  - Figure 8 needs an explicit reference solution, hardware specification, and interpretation threshold
  - Figure 10 should be labeled as a descriptor-wiring or stress test, not as a calibrated physiological sensitivity study
  - Table 21 should say what convergence claim, if any, follows from the stationary-Stokes rows

**Fallback if not completed.** Remove or sharply qualify any appendix item whose governing question and interpretation cannot be stated in one or two sentences.

## Editorial Cleanup

### Appendix scope

- Trim Appendix D down to notation and functional-analytic material that is actually needed to disambiguate the thesis
- Remove the Heine-Borel discussion, generic Banach-space statements, and basic multi-index material unless a later argument depends on them directly
- Remove Appendix F's brief Navier-Stokes well-posedness and continuation discussion unless it serves a specific argument later in the report

### Figures and tables

- Split Figure 3 into separate C23 and C40 panels
- State explicitly in the Figure 4 caption that the vertical axis does not begin at zero
- Keep Figure 5 as the clearest main-result figure
- Split Table 7 into a physical or model matching table and a numerical or observation matching table
- Rename `tmax |q|` in Table 11 to `time of peak max_i |q_i|`
- Mark the radial targets in Table 8 as generated but excluded from retained evidence

### Bibliography cleanup

- Remove internal workflow notes from the rendered bibliography, including phrases such as `Used as broad cardiovascular-modeling background`, `Poster`, `Infrastructure citation only`, and `Verification-resource citation only`
- Use ISO access dates such as `2026-05-07`
- Before submission, check whether recent arXiv records now have final journal metadata and update them where appropriate

### Copyediting

- Change `manufactured solution method` in the acronym list to `method of manufactured solutions`
- Replace `The case study is not the organizing limit of the literature review` with `The case study does not delimit the scope of the literature review`
- Replace `The next modeling step is a boundary lane...` with `The next modeling study should compare...`
- Check that open and closed time intervals remain visibly distinguishable in the rendered PDF
- Ensure every table containing derivatives, integrals, or residuals gives units or states plainly that the quantities are in solver-coordinate units
- Add a List of Figures and List of Tables if the graduate-school format requires them

## Recommended Revision Sequence

1. Correct abstract and conclusion claim language, `q` versus `Q_phys` reporting, and timestamp wording.
2. Separate wall-law pressure notation from observed three-dimensional pressure.
3. Replace reproducibility placeholders with concrete archival and environment information, and fix the command-block typography.
4. Decide whether the grid-sensitivity study and plane-cut operator validation will be completed before submission.
5. If those studies are not completed, narrow the claim language and reduce numerical precision accordingly.
6. Diagnose or remove unresolved appendix diagnostics.
7. Trim the general-analysis appendices and finish the figure, table, bibliography, and copyediting pass.

## Time-Constrained Fallback

If there is not enough time to run new computations before submission, the manuscript can still be made defensible by completing all submission blockers, removing or sharply qualifying unresolved appendix diagnostics, stating plainly that the 1D-3D comparison values are single-grid descriptors, and reducing any over-precise numerical reporting. In that form, the thesis still stands as a disciplined numerical audit and case study rather than a stronger evidence package for grid-stable cross-model agreement.

## Final Judgment

The manuscript is defensible as a master's thesis because it treats the implementation as an auditable numerical object and carefully limits its claims. It is not yet evidence of predictive stenosis accuracy, but it does not need to be. Its strongest contribution is the disciplined connection among model hierarchy, closure choices, verification, equilibrium preservation, and observation operators.

After the targeted revisions above, I would regard it as ready for final submission. The strongest optional additions are the production-grid sensitivity study and the plane-cut operator validation. If those additions are not completed, final submission is still plausible provided the manuscript narrows claims, reduces precision where appropriate, and avoids overinterpreting single-grid or partially validated evidence.
