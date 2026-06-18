Editorial assessment

The manuscript has several strong foundations: it is unusually disciplined about claim boundaries, distinguishes reduced outputs from clinical quantities, documents the cross-section quadrature operator, and takes reproducibility seriously. The claim–evidence matrix on page 5 is especially effective.

The manuscript nevertheless requires major revision before its mathematical and numerical claims are fully auditable. The most consequential mathematical issue is an internal inconsistency between the displayed pressure–area law and the elastic flux/source pair used by the solver. The main narrative issue is that the actual contribution—the extended 1D implementation and 3D velocity diagnostic—does not emerge until after roughly twenty pages of textbook-style continuum background. The report currently reads as four partially integrated documents: a continuum-mechanics primer, a model-hierarchy review, a software-verification report, and a preliminary cross-model study.

Review plan applied

I evaluated the manuscript in four passes:

1. Claim-to-evidence audit: whether each claim is supported by the reported analysis.
2. Mathematical consistency audit: notation, dimensional consistency, derivations, closure assumptions, and agreement between the continuous model and implemented operator.
3. Numerical-evidence audit: verification design, error metrics, boundary treatment, and cross-model comparison.
4. Narrative audit: research focus, ordering, redundancy, literature synthesis, and the relationship between figures, results, and conclusions.

The revisions below are ordered by importance.

I. Highest-priority mathematical revisions

1. Resolve the pressure-law versus flux/source inconsistency

This is the most serious internal issue.

On page 22, Definition 1.29 gives the radius-squared pressure law as

p_{1,g}(a,z,t)
=
p_{\mathrm{ext}}(z,t)
+
\frac{K}{R_0(z)^2}
\left(\sqrt a-R_0(z)\right).

But page 23 and Appendix G use

\Psi_h(a)
=
\frac{K}{3\rho R_{\max}^2}a^{3/2},
\qquad
\partial_a\Psi_h(a)
=
\frac{K}{2\rho R_{\max}^2}\sqrt a,

together with a geometry source containing R_{\max}^{-2}.

The manuscript itself defines the compatibility requirement

\partial_a\Psi
=
\frac{a}{\rho}\partial_a p_{1,g}.

For the pressure law displayed on page 22, the right-hand side is

\frac{K}{2\rho R_0(z)^2}\sqrt a,

which is not the derivative of the implemented potential unless R_0(z)=R_{\max}. Freezing the denominator at R_{\max} is not merely a notation change; it changes the wall law and its geometry source.

The revision should do one of the following:

* Make the implemented wall law explicitly
    p_{1,g}
    =
    p_{\mathrm{ext}}
    +
    \frac{K}{R_{\max}^2}(\sqrt a-R_0),
    and derive the displayed potential and source from it; or
* Retain the local R_0(z)^{-2} law and derive a flux/source pair that satisfies the compatibility identity; or
* State clearly that R_0^{-2}\mapsto R_{\max}^{-2} is a numerical approximation, derive the additional consistency error it introduces, and test its effect.

A compact proposition should show that the chosen rest state a=R_0^2,\ q=0 is an exact equilibrium of both the continuous and discrete operators. At present, the implemented R_{\max}-based pair appears constructed to preserve that equilibrium, but the main-text pressure law does not match it.

2. Enforce one notation system for physical and solver variables

Definition 1.30 appropriately distinguishes

A_{\mathrm{phys}}=\pi a,
\qquad
Q_{\mathrm{phys}}=\pi q,
\qquad
\bar u=q/a.

Appendix G then reuses Q for the solver variable paired with a. The output conventions also call the solver coordinate A cm2 and the scaled flow coordinate Q cm3 s. This makes it difficult to determine whether individual formulas contain physical flow Q_{\mathrm{phys}} or scaled flow q.

Use the following convention everywhere:

(A,Q) \quad \text{physical area and flow},
\qquad
(a,q)=(A/\pi,Q/\pi) \quad \text{solver coordinates}.

Then rewrite Appendix G with U_h=(a_i,q_i), not (a_i,Q_i). Rename exported fields accordingly:

* a_cm2
* q_cm3_s
* Aphys_cm2
* Qphys_cm3_s
* uavg_cm_s

This single edit will remove a substantial fraction of the manuscript’s cognitive burden and make dimensional checks much easier.

3. Correct the logic connecting no-slip and the parabolic profile

Definition 1.26 currently suggests that a no-slip antecedent becomes the parabolic closure \alpha_P=4/3,\ g_P=4 after averaging. No-slip alone does not imply a parabolic velocity profile in an unsteady stenotic vessel. A parabolic profile follows from additional assumptions such as straight circular geometry, Newtonian flow, and fully developed laminar conditions.

A more accurate formulation would be:

The baseline reduced model assumes a parabolic cross-sectional profile. This profile is compatible with no-slip for fully developed Newtonian flow in a straight circular tube, but it is an independent closure assumption in the stenotic and transient setting.

For the same reason, classical-1d-no-slip should preferably be renamed classical-1d-parabolic-profile, unless no-slip is being used only as historical provenance.

4. Clarify or repair the non-Newtonian extension of the p_2 correction

Definition 1.29 defines

p_{2,g}
=
g_P\rho\nu_{\mathrm{eff}}^{\mathcal R}
\frac{q}{a}\frac{R_0'}{R_0}.

Appendix G.3 differentiates the factors q, a, and R_0, but does not include a derivative of \nu_{\mathrm{eff}}^{\mathcal R}(\dot\gamma). For a non-Newtonian realization,

\partial_z p_{2,g}

generally contains a term proportional to \partial_z\nu_{\mathrm{eff}}. The current formula is exact only for constant viscosity, or under a deliberate “locally frozen viscosity” approximation.

The manuscript should either:

1. Restrict the Canic p_2 correction to the Newtonian model;
2. State that effective viscosity is frozen when differentiating p_2, and call this a computational closure rather than a derived generalized-Newtonian law; or
3. Compute p_{2,g} at cells and apply the declared discrete derivative D_z^h p_{2,g}. That approach automatically includes spatial variation of effective viscosity and avoids differentiating the nonsmooth max regularization and viscosity projection analytically.

Also clarify that the quantity called \partial_{dz}p_2 in Appendix G is apparently a density-scaled pressure derivative. As written, the factor 1/\rho is hidden.

5. Separate isotropy from frame indifference

Remark 1.12 equates isotropy with independence of the selected coordinate system. Coordinate-frame independence is principally an objectivity or frame-indifference requirement; isotropy concerns material symmetry. These concepts are related in the representation of constitutive laws but are not identical.

The constitutive subsection should say, more precisely, that an objective isotropic linear constitutive mapping of the symmetric rate tensor has the Newtonian form

\mathbf T=-p\mathbf I+2\eta\mathbf D+\lambda\,\operatorname{tr}(\mathbf D)\mathbf I.

The heading “Blood isotropy justification” should also be reconsidered. The cited evidence discussed there concerns scale-dependent apparent viscosity more directly than isotropy.

6. Tighten the analytic classification claims

The statement that “positive regular viscosity laws” give the usual parabolic–elliptic interpretation is too weak mathematically. Pointwise positivity of \eta_{\mathrm{eff}} does not by itself ensure uniform ellipticity or monotonicity of the nonlinear stress operator

\mathbf S(\mathbf D)
=
2\eta_{\mathrm{eff}}\!\left(\sqrt{2\mathbf D:\mathbf D}\right)\mathbf D.

Either state the relevant coercivity, growth, and monotonicity assumptions, including a positive lower bound where uniform parabolicity is claimed, or replace the analytic classification with a less theorem-like description.

Similarly:

* Allowing \eta_{\min}=0 admits degeneracy.
* Casson and power-law regularizations change the constitutive law and should be described as regularized computational models.
* The global Navier–Stokes regularity discussion on pages 15–16 is not needed for the reported 1D computation. If retained, distinguish global weak existence from unresolved global strong regularity and avoid using the Clay problem as general-purpose well-posedness context for a bounded moving vessel.

7. Make the selected extended 1D equation explicit in the main text

The main formulation uses a generic \alpha, but the implementation uses

\alpha_{\mathrm{eff}}(z)
=
\alpha_P+\alpha_c(R_0'(z))

and adds an \alpha_c'-dependent source. The actual model therefore cannot be reconstructed from Equations (1.1)–(1.8) alone.

Place one definitive model statement in Section 1.4:

\partial_t a+\partial_z q=0,

\partial_t q+
\partial_z\!\left[
\alpha_{\mathrm{eff}}(z)\frac{q^2}{a}
+
\Psi(a,z)
\right]
=
S_{\mathrm{wall}}(a,z)
+
S_{\mathrm{fric}}(a,q,z)
+
S_{\alpha}(a,q,z)
+
S_{p_2}(a,q,z).

Define every term immediately below it and state which terms disappear in the classical baseline. At present, readers must reconcile several definitions and Appendix G to infer the selected equation.

8. Strengthen the pressure-observation convention

Convention C.3 says the pressure observation maps do not have to preserve constant shifts. That weakens the physical meaning of the gauge-to-reference conversion. For taps and averages, impose

\mathcal O[p+c]=\mathcal O[p]+c.

Then adding p_{\mathrm{ref}} after observation is gauge-consistent. The admissibility criterion should also be stronger than a merely nonzero mean denominator. For numerical and physical stability, require something like

\left\langle P_{\mathrm{prox}}^{\mathrm{ratio}}\right\rangle_{T_{\mathrm{HF}}}
\ge P_{\min}>0.

Because no pressure ratio is actually computed, most of this formalism could be shortened and moved to an appendix or future-work subsection.

II. Numerical verification needs a more rigorous design

9. Separate software QA, numerical verification, and model validation

Section 2.1 currently combines:

* test-suite status,
* backend comparisons,
* self-convergence,
* rheology sensitivity,
* GPU/CPU differences,
* boundary diagnostics,
* and cross-model comparison.

These do not provide the same kind of evidence.

Use three explicit categories:

Software quality assurance: unit tests, descriptor parsing, file schemas, CPU/MPS consistency, package reproducibility.

Numerical verification: manufactured solutions, exact equilibria, grid convergence, time convergence, conservation, positivity, and boundary implementation.

Model comparison or validation: comparison with another computational model or physical observations. The present 3D comparison is a computational cross-model diagnostic, not validation.

“128 rows OK” demonstrates that checks ran; it does not communicate what mathematical property was tested or the accepted tolerance. Table 1 should therefore list the tested property, metric, threshold, and observed result.

10. Add verification problems with known answers

Self-convergence alone does not establish correctness. The following tests would exercise the central implementation far more effectively:

1. Geometry-rest equilibrium
    a(z)=R_0(z)^2,\qquad q(z)=0.
    Report the continuous residual, discrete residual, and drift over time.
2. Constant-radius steady-flow test with a known frictional pressure gradient.
3. Linearized wave test on a uniform vessel with an analytical or high-accuracy reference solution.
4. Manufactured variable-geometry solution that activates the elastic source, \alpha_c' term, and p_2 derivative.
5. Separate temporal refinement: hold the spatial grid fixed and refine \Delta t.
6. Separate spatial refinement: choose a time step small enough that temporal error is negligible.

For each test, show the raw error sequence and compute

p_h
=
\frac{\log(E_h/E_{h/2})}{\log 2}.

Figure 8’s medians and min–max whiskers conceal whether an asymptotic convergence regime has been reached. Log–log error curves and a compact numerical table would be much more persuasive.

11. Document the actual MUSCL operator

Table 3 identifies the selected method as MUSCL with a minmod limiter, but Appendix G.3 presents an interface flux in terms of generic U^\pm and then says the realization uses neighboring first-order states. That is ambiguous.

State explicitly:

* slope formula,
* limiter definition,
* left/right reconstruction,
* whether reconstruction is performed in conservative or primitive variables,
* source reconstruction or quadrature,
* treatment next to boundaries,
* positivity limiting,
* and whether the same reconstruction is used by every backend.

The DG p0/p1/p2 results in Figure 8 are not supported by a corresponding method description. Either document the DG discretization or move those results to a software supplement.

12. Record positivity and conservation effects

The SSPRK stages apply a projection \Pi to the area coordinates. Such a projection can modify mass conservation and formal order. The manuscript acknowledges that positivity events were not persisted for the comparison runs, which prevents the reader from knowing whether the reported solution was produced by the nominal scheme or by repeated clipping.

Every run supporting a result should record:

* minimum a,
* projection activation count,
* total projected correction,
* minimum and maximum realized CFL,
* accepted step count,
* mass-balance defect,
* and NaN/finite-state checks.

If the projection is never activated, say so. If it is activated, quantify its effect or replace it with a documented positivity-preserving limiter.

13. Rework backend “agreement” metrics

Figure 9 reports a “max final-state L_2 difference,” but the normalization, component scaling, and units are not clear. Area and flow have incompatible dimensions and should not be combined into an unscaled state norm.

Report componentwise nondimensional errors, for example,

E_a
=
\frac{\|a^{(1)}-a^{(2)}\|_2}
{\|a^{(1)}\|_2},
\qquad
E_q
=
\frac{\|q^{(1)}-q^{(2)}\|_2}
{\|q^{(1)}\|_2}.

Also document solver tolerances and whether the SciML path applies the same positivity treatment. If the native path includes stage projections but the SciML path only integrates \dot u=L_h(u,t), the two backends are not solving identical fully discrete problems.

“Cross-integrator discrepancy” is more accurate wording than “backend agreement” unless an acceptance threshold is specified and met.

14. The boundary approximation requires direct evidence

Appendix G.5 uses \alpha=1, fixed-area Riemann invariants for a solver with variable \alpha_{\mathrm{eff}} and geometry sources. The approximation is disclosed, but its influence is not quantified.

Before using the final state in a cross-model comparison, add at least one of:

* a characteristic boundary treatment based on the actual flux Jacobian;
* a linearized incoming-characteristic condition for the full model;
* a vessel-length sensitivity test;
* an outlet-condition sensitivity test;
* or a measured reflection coefficient.

A constant inflow imposed on a rest state creates a start-up wave. The manuscript must show whether t=1 s is still influenced by the initial transient and outlet reflections. A time trace of inlet, throat, and outlet a,q,\bar u is essential.

III. Rebuild the 1D–3D comparison as a controlled diagnostic

15. Add a complete model-matching matrix

The comparison is commendably cautious, but the mismatch is described primarily through disclaimers rather than quantified inputs. Add a table with a row for each of the following:

* reference geometry and current geometry,
* wall model,
* density and viscosity,
* initial condition,
* inlet condition and waveform,
* outlet condition,
* time origin and transient history,
* numerical resolution,
* velocity representation order,
* and pressure availability.

Mark each item as matched, approximately matched, unmatched, or unknown.

Until that table is complete, call the 3D data a “comparison dataset,” not a reference solution.

16. Demonstrate that the snapshot is temporally comparable

The 1D state is evaluated at 1.0 s and the 3D data at approximately 0.9995 s. The 5\times10^{-4} s difference is probably small, but its significance depends on the transient derivative. More importantly, the two simulations have unmatched histories.

The preferred comparison is one of:

* interpolation of both models to the same time;
* a time-window comparison;
* a periodic steady-state phase comparison;
* or a genuinely steady comparison.

If only the single 3D snapshot is available, show that the 1D solution is locally stationary near t=1, or bound the expected temporal discrepancy using adjacent 1D outputs.

17. Separate flow mismatch from area mismatch

The cut-area audit is a strong idea, but its implications are not carried into the velocity analysis. The maximum cut-area discrepancies are 2.94% and 4.46%, large enough to matter near the stenosis.

Use the identity

\frac{Q_{1D}}{A_{1D}}-\frac{Q_{3D}}{A_{3D}}
=
\frac{Q_{1D}-Q_{3D}}{A_{1D}}
+
Q_{3D}
\left(
\frac{1}{A_{1D}}-\frac{1}{A_{3D}}
\right)

to decompose velocity discrepancy into:

* a flow component, and
* a geometry/area component.

Plot \epsilon_A(z), |e_Q(z)|, and |e_u(z)| together. Report where the maximum area error occurs and test whether the largest velocity errors coincide with cut-area errors.

The area-audit statement should also be more exact: the median discrepancy is below 0.3%, but the maximum is several percent. “Sub-percent typical discrepancy with localized multi-percent outliers” is clearer.

18. Improve the section-error metrics

The present metrics are transparent but should be described as empirical sample metrics:

* mean absolute error,
* root-mean-square error,
* maximum absolute error.

Calling them L_1,L_2,L_\infty invites confusion with continuous function-space norms. If a normalized axial norm is desired, use quadrature weights:

E_p
=
\left(
\frac{1}{L}
\sum_j w_j |e(z_j)|^p
\right)^{1/p}.

This also handles endpoints correctly. The abstract would be clearer if it reported “MAE, RMSE, and maximum absolute discrepancy.”

19. Make the radial comparison geometrically and statistically defensible

The radial comparison currently assigns each cut triangle to a radial bin using its centroid. A triangle crossing a bin boundary is therefore allocated wholly to one annulus. With only twenty bins, this introduces an uncontrolled binning error.

A stronger operator would clip cut triangles against annular bin boundaries and integrate over the resulting pieces. At minimum, include a 10/20/40-bin sensitivity study.

The radial analysis should also:

* use annular-area-weighted aggregate errors for physical interpretation;
* retain the current unweighted metric only as a profile-shape diagnostic;
* report within-bin azimuthal variance, because radial averaging discards skewness and secondary-flow structure;
* distinguish r/R_0 from normalization by the current 1D radius \sqrt a;
* and state the exact reconstructed 1D profile formula in Section 2.

The statement that discrepancies are “consistent with” secondary flow, skewness, or separation should be recast as a hypothesis. The current diagnostic does not uniquely identify which omitted phenomenon caused the mismatch.

20. Add resolution and operator sensitivity to the comparison

The general package convergence study is not a substitute for convergence of the actual C23 and C40 comparison outputs. At minimum, recompute the comparison at:

* N=200,400,800 for the 1D grid;
* multiple time-step caps;
* 100, 200, and 400 target planes;
* and multiple radial-bin resolutions.

If a second 3D mesh is unavailable, explicitly identify 3D discretization uncertainty as unquantified. Node count alone is not a mesh-resolution statement; report element count, field order, and characteristic mesh size near the throat.

IV. Add physical and asymptotic context

21. Characterize the operating regime

The reader should not have to infer whether the computation is in the regime where the reduced assumptions are plausible. Add a case table reporting:

* healthy and throat Reynolds numbers;
* Womersley number if a pulsatile waveform is introduced;
* maximum u/c or characteristic Mach number;
* minimum and maximum area;
* maximum |R_0'|;
* a vessel slenderness parameter;
* and radius versus area stenosis severity.

This is especially important for the 50% and 73% sensitivity cases in Figure 10. High severity and steep geometry may lie outside the asymptotic regime motivating a 1D reduction. The manuscript should not present those cases without a model-admissibility discussion.

The numerical experiment uses a constant inlet applied to a rest state. Unless there is a periodic waveform elsewhere in the code record, describe this as a start-up transient, not a physiological pulse-wave simulation.

V. Narrative restructuring

22. Put the actual study before the general continuum tutorial

The strongest structure would be:

1. Introduction

Problem, gap, contributions, research questions, and claim boundary.

2. Selected model and assumptions

Geometry; physical variables; solver variables; wall law; extended terms; initial and boundary conditions; parameter table; regime indicators.

3. Numerical method and verification

Finite-volume operator; source discretization; boundary method; positivity; grid/time verification; reproducibility statement.

4. Cross-model comparison protocol

3D data, matching matrix, quadrature operator, metrics, and audit tests.

5. Results

Verification first, followed by C23/C40 comparison and sensitivity.

6. Discussion

What the patterns plausibly mean, what cannot be attributed, relation to the literature, and dominant limitations.

7. Conclusions

Move the material derivative, Reynolds transport theorem, coordinate forms, generic function-space definitions, and most of the 3D model hierarchy to appendices. These topics are valid, but they currently delay the research problem and create the impression that foundational exposition is itself a contribution.

23. Convert the literature review from description to synthesis

The current review explains what 3D, 2D, 1D, and 0D models are, but it rarely compares evidence, assumptions, or unresolved issues across sources. A literature review should establish:

1. What classical 1D models retain and omit.
2. Why stenotic geometry is difficult for classical 1D closures.
3. What the Canic extension changes mathematically.
4. Which parts of that extension this manuscript adopts or modifies.
5. What prior validation or numerical evidence exists.
6. What gap the present implementation and output operator address.

A synthesis table could compare model family, wall closure, profile assumption, stenosis correction, boundary treatment, and type of supporting evidence. This would be more valuable than several pages of general hierarchy description.

The manuscript should also distinguish inherited material from original work. State plainly that the governing extended model is adopted from the cited Canic work, while the implementation, benchmark framework, geometry/operator audit, or comparison workflow constitute the report’s contribution.

24. Consolidate the scope disclaimers

The manuscript repeats variants of “not clinical validation,” “not FFR evidence,” “not patient-specific,” and “not resolved-FSI evidence” in the introduction, section openings, captions, results, and conclusion. The caution is appropriate, but the repetition interrupts the argument and sometimes makes the prose defensive.

Retain the excellent claim–evidence table on page 5, rename it “Scope and evidence matrix,” and rely on it. Repeat a limitation only where a result could otherwise be misread.

Figure captions should explain what a figure shows, not restate the entire evidence boundary.

25. Add a genuine Discussion section

The current manuscript moves almost directly from results to conclusions. A Discussion section should address:

* why C40 differs more than C23;
* how much of the discrepancy may arise from area, flow, wall, boundary, and transient mismatch;
* whether the error localization supports or challenges the extended closure;
* which conclusions are robust under the available sensitivity tests;
* and which experiment would discriminate among competing explanations.

That is also the proper place to reconnect the results to the literature reviewed in Section 1.

26. Move software-engineering detail out of the scientific results

The CPU/MPS timing comparison, long command invocations, package stage counts, and four pages of hashes are valuable reproducibility assets but impede the scientific narrative.

Keep in the paper:

* exact software release or commit;
* environment file;
* archive identifier;
* one regeneration command;
* and a concise data manifest.

Move individual hashes and device-specific performance plots to a machine-readable manifest or repository supplement. Figure 12 is primarily a software portability result and does not advance the hemodynamic argument.

VI. Section-specific editorial actions

Abstract, page 1

The abstract contains the right quantitative results and an appropriately limited interpretation. Improve it by:

* identifying the selected numerical method;
* replacing “L_1/L_2/L_\infty” with MAE/RMSE/maximum discrepancy;
* avoiding undefined implementation language such as “closure-health checks”;
* and stating the central contribution before listing package checks.

“Backend agreement” should not appear until a tolerance and normalized metric have been defined.

Introduction, pages 4–5

The three research questions are useful and should remain. Add a one-paragraph novelty statement distinguishing adopted model equations from original implementation and diagnostic work.

The “Literature Review Roadmap” mostly repeats the table of contents and can be deleted.

Continuum foundations, pages 6–16

Condense to approximately two pages in the main text:

* continuum assumption;
* incompressible generalized-Newtonian equations;
* stress law;
* fixed versus moving wall distinction.

Move the flow-map theorem, Reynolds transport proof, function-space material, global regularity aside, and cylindrical-coordinate equations to appendices.

Model hierarchy, pages 16–20

Figure 4 communicates most of the conceptual point. The following subsections repeat similar statements about what each tier cannot do. Replace them with one comparison table and a short synthesis.

Clinical motivation, pages 25–27

Because the manuscript reports no pressure result, this section is disproportionately long. Reduce it to a paragraph in the introduction and move the detailed pressure-ratio convention to an appendix. Otherwise readers expect pressure or FFR results that never arrive.

Verification section, pages 28–32

Rename it “Software QA and numerical verification.” Replace status counts and performance plots with:

* exact verification problem;
* error definition;
* refinement sequence;
* expected order;
* observed order;
* acceptance threshold;
* and pass/fail conclusion.

The rheology/profile sensitivity figure requires a parameter table and a clearer interpretation. If it is not used to support a research question, move it to supplementary material.

Cross-model comparison, pages 32–37

This is the strongest and most original part of the manuscript. Preserve the quadrature derivation, but add:

* the matching matrix;
* actual 3D discretization metadata;
* transient-status evidence;
* area/flow decomposition;
* error-versus-z panel;
* and operator-sensitivity results.

Figure 14 should become the central results figure. Add a lower panel showing \bar u_{1D}-\bar u_{3D}, and optionally overlay the area-audit discrepancy.

Conclusions, page 38

Answer the three research questions explicitly rather than repeating the scope language. A strong conclusion would distinguish:

1. what model was defined;
2. what numerical behavior was verified;
3. what the comparison showed;
4. and what remains indeterminate.

The stationary-Stokes extension should be described as a geometry/implementation verification tier, not as a physically stronger stenosis-flow model. For the reported Reynolds regime, neglecting inertia may make it unsuitable for interpreting jets or recirculation.

Appendices, pages 39–70

The appendices contain useful material but are overexpanded.

* Merge Appendices B, C, and D into a concise notation appendix.
* Remove definitions of standard C^k and L^p spaces unless used in a theorem.
* Replace the rheology descriptor R, which conflicts with vessel radius R, with \mathcal R or rheo.
* Ensure the open and closed time intervals are visually distinguishable.
* Retain the derivation and numerical-operator appendices after resolving the continuous/discrete model inconsistency.
* Replace the printed hash inventory with a machine-readable manifest.

Suggested tighter abstract

This study formulates and numerically evaluates an extended one-dimensional compliant-vessel model for flow through a smooth idealized stenosis. Physical area and flow variables are mapped explicitly to the radius-squared coordinates used by a MUSCL finite-volume and SSPRK3 implementation. Numerical verification examines equilibrium preservation, refinement behavior, and cross-integrator discrepancies. At t=1.0 s, section-averaged axial velocities are compared with two three-dimensional computational datasets using plane–tetrahedron quadrature. For 23% and 40% radius reductions, the mean absolute discrepancies are 0.505 and 0.966 cm/s, the root-mean-square discrepancies are 0.664 and 1.87 cm/s, and the maximum discrepancies are 2.35 and 9.92 cm/s. Errors are concentrated near the stronger stenosis and in reconstructed radial profiles. Because wall models, boundary conditions, and transient histories are not fully matched, these results identify where the models differ rather than validating the 1D model. The principal contribution is a reproducible model specification and cross-sectional comparison operator for subsequent matched verification and pressure–flow studies.

Recommended revision sequence

First, correct the mathematical specification. Resolve the R_0 versus R_{\max} wall law, standardize A,Q,a,q, define the full extended balance law, and clarify the non-Newtonian p_2 treatment.

Second, rerun the evidence-generating cases. Persist CFL, positivity, conservation, boundary, temporal, and grid-refinement diagnostics. Add equilibrium and manufactured-solution tests.

Third, rebuild the comparison. Supply the model-matching matrix, decompose area and flow effects, improve radial integration, and perform grid/operator sensitivity.

Fourth, rewrite the narrative around the actual contribution. Move general continuum material to appendices, synthesize rather than catalog the literature, add a Discussion section, and transfer software manifests and hardware benchmarking to supplementary material.

After those revisions, the manuscript would present a much clearer and more defensible contribution: not a broad validation of stenotic blood-flow prediction, but a precisely specified, reproducibly implemented reduced model with a carefully delimited computational comparison operator.
