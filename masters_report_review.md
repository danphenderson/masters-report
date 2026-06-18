# Second Independent Editorial Review and Final Revision Plan

**Manuscript:** *Mathematical Simulation of Blood Flow: A Literature Review and Idealized Stenosis Study*
**Author:** Daniel Henderson
**Review basis:** Complete second reading of all 68 pages, including figures, tables, appendices, notation, numerical-method statements, and references.

## Editorial judgment

The manuscript has a strong technical foundation and an unusually careful attitude toward scope, reproducibility, and overclaiming. Its most defensible contribution is not clinical hemodynamic prediction. It is a **mathematical model contract, a documented 1D implementation, a software-verification record, and a preliminary cross-model velocity diagnostic**.

I recommend **major revision before final submission**, primarily because the present structure obscures that contribution and because several mathematical and numerical definitions do not yet connect cleanly enough to the implemented experiment. The necessary changes are achievable without turning the report into a new research project.

The strongest features to preserve are:

- explicit distinctions among 0D, 1D, 2D, 3D, and FSI model roles;
- disciplined separation of model outputs from clinical measurements;
- unusually detailed unit and provenance conventions;
- a reproducible Julia/Python benchmark pipeline;
- candid reporting of large near-throat discrepancies rather than selective presentation.

The most important weaknesses are:

1. **The narrative promise and delivered evidence are misaligned.** Pressure ratio and FFR motivation receive substantial space, but the completed experiment is velocity-only.
2. **The selected continuum/1D model is not fully bridged to the radius-squared extended solver.** The reader must infer how the wall law, physical area-flow equations, Canic corrections, and stored variables correspond.
3. **The current 3D observation operator is not a physical cross-sectional mean.** Arithmetic averaging of mesh nodes produces a useful sampling diagnostic, but it should not be called a section mean without qualification.
4. **Several numerical metrics and pass/fail labels are undefined.** This affects the interpretation of Tables 2-5 and Figures 11-15.
5. **There are two substantive mathematical points requiring correction or qualification:** the strict-hyperbolicity statement for general alpha, and the use of alpha-equals-one Riemann invariants with an interior model using alpha greater than one.
6. **The manuscript is over-formalized in the main body and over-documented in the appendices.** Definitions, conventions, code identifiers, future notation, and repeated disclaimers compete with the scientific argument.

## Recommended scope decision

The manuscript should make an explicit choice between two possible final identities.

### Recommended track: velocity-focused mathematical and numerical study

Keep the completed evidence and revise the framing to emphasize:

- mathematical formulation and model hierarchy;
- implementation of an extended 1D stenosis model;
- code and solution verification;
- a preliminary 1D-versus-resolved-3D velocity comparison under a declared observation operator;
- limitations and requirements for future pressure validation.

Under this track, shorten the clinical pressure-ratio material to motivation and future work. Do not imply that pressure or FFR is a principal result.

### Alternative track: pressure-flow study

Retain the current prominence of pressure-ratio motivation only if the final manuscript adds:

- computed pressure-drop traces;
- a fully specified pressure reference;
- proximal and distal observation operators;
- a declared averaging window;
- matched 3D or experimental pressure data;
- uncertainty and denominator-admissibility analysis.

This is a materially larger project. Unless those data are already available, the velocity-focused track is the stronger final manuscript.

## Revision priorities

| Priority | Revision | Completion test |
|---|---|---|
| P0 | Separate physical and solver variables | No A/Q ambiguity |
| P0 | State the implemented extended model | Main equations match code |
| P0 | Correct hyperbolicity conditions | Radicand condition stated |
| P0 | Qualify boundary invariants | Exact or approximate declared |
| P0 | Redefine the 3D observation operator | Quadrature or renamed statistic |
| P0 | Define every error and benchmark metric | Formula and units supplied |
| P0 | Add full parameter tables | Run reproducible from manuscript |
| P1 | Reorder verification before comparison | Scientific sequence is clear |
| P1 | Rewrite abstract and introduction | Results and claims align |
| P1 | Consolidate repeated limitations | One claim-evidence section |
| P1 | Explain anomalous velocity features | Negative dip addressed |
| P2 | Reduce appendices and hash tables | Human-readable main document |
| P2 | Improve figure scale and legends | Readable in print |
| P3 | Add optional pressure/2D studies | Only if scope permits |

---

# 1. Narrative and organization

## 1.1 State research questions and original contributions

The introduction currently poses a broad question about geometry, wall properties, rheology, and boundary data, then moves quickly into model vocabulary. It should instead identify two or three answerable questions, such as:

1. What assumptions and closures define the selected stenosis-aware 1D model?
2. Does the implementation exhibit the expected numerical behavior under self-convergence and backend checks?
3. Under a declared velocity observation operator, where does the 1D solution differ from the available resolved 3D data?

Follow those questions with a short list of original contributions. A suitable contribution statement would be:

> This report contributes a consistent model-and-output specification for an idealized stenotic vessel, a reproducible implementation and benchmark suite for the selected extended 1D model, and a preliminary comparison that localizes velocity discrepancies relative to two resolved 3D datasets. The comparison is diagnostic rather than clinical or experimental validation.

This is clearer and stronger than describing the contribution primarily as “fixing vocabulary.”

## 1.2 Move clinical motivation earlier, then reduce it

The anatomy-function distinction is important, but it appears after approximately twenty pages of continuum and model-hierarchy material. Move a concise version to the first two pages of the introduction.

Then shorten the present Section 1.4. If the report remains velocity-focused, retain only:

- why geometry alone does not determine functional obstruction;
- why pressure drop is a future output of interest;
- why the present results are not FFR or CT-FFR.

The detailed ratio-output convention can remain in an appendix. Figures 7 and 8 should either move to the introduction or be reduced to one figure. Five pages of pressure conventions before a velocity-only experiment creates a promise-result mismatch.

## 1.3 Create a real separation between review, model, methods, and results

The current Chapter 1 simultaneously functions as introduction, literature review, mathematical foundations, model specification, clinical motivation, and methods preface. This makes the report harder to navigate.

A clearer final structure is:

### Proposed chapter structure

1. **Introduction**
   - motivation;
   - research questions;
   - contributions;
   - evidence and claim boundaries;
   - chapter roadmap.

2. **Literature Review and Model Hierarchy**
   - continuum and rheology in concise form;
   - 0D/1D/2D/3D/FSI comparison;
   - stenosis-specific reduced models;
   - selection of the extended 1D model.

3. **Selected Model and Numerical Method**
   - physical area-flow equations;
   - wall and rheology assumptions;
   - physical-to-solver variable map;
   - extended variable-radius terms;
   - finite-volume/DG discretization;
   - time integration and boundary states.

4. **Verification and Reproducibility**
   - exact or manufactured tests;
   - self-convergence;
   - conservation and positivity;
   - backend agreement;
   - benchmark thresholds and environment.

5. **Resolved-Velocity Comparison**
   - matched case definitions;
   - geometry and boundary-data correspondence;
   - 3D observation operators;
   - error definitions;
   - results and sensitivity;
   - limitations.

6. **Discussion and Conclusions**

This order makes verification precede cross-model comparison, which is the correct scientific sequence.

## 1.4 Reduce textbook derivations in the main body

The flow map, material derivative, Reynolds transport theorem, stress decomposition, and coordinate formulas are mathematically correct background topics, but the main body currently gives them nearly equal weight to the original numerical work.

Retain in the main text:

- continuum scale assumption;
- incompressibility and mass balance;
- Newtonian/generalized-Newtonian stress;
- governing Navier-Stokes system;
- cross-sectional variables;
- selected 1D balance law;
- selected wall law.

Move or leave in appendices:

- proof-level Reynolds transport details;
- Jacobian evolution derivation;
- full cylindrical component formulas;
- basic Banach-space definitions;
- future passive-scalar notation;
- full closure catalogs not used in the reported comparison.

The main narrative will improve if each background subsection ends with one sentence explaining how it supports the selected model.

## 1.5 Replace repeated disclaimers with a claim-evidence matrix

The manuscript repeatedly states that figures are not clinical data, not pressure evidence, not FFR, and not validation. The caution is appropriate, but repetition weakens the prose.

Use one compact matrix near the end of the introduction:

| Claim | Evidence | Permitted wording |
|---|---|---|
| Model formulation | Derivation and literature | “Defines” |
| Code behavior | Tests and self-convergence | “Verifies selected properties” |
| Backend agreement | Same spatial operator | “Agrees for reported metrics” |
| 1D/3D velocity | Node or quadrature operator | “Diagnostic comparison” |
| Pressure accuracy | None | “Future work” |
| Clinical validity | None | No claim |

Thereafter, use concise captions and avoid repeating the full limitation list.

## 1.6 Improve the abstract

The current abstract is accurate but does not report the main numerical findings. It foregrounds conventions and software surfaces rather than the scientific result.

### Proposed revised abstract

> This report develops a mathematical and numerical framework for idealized stenotic blood-flow simulation, connecting incompressible Navier-Stokes and generalized-Newtonian continuum models to reduced 0D, 1D, 2D, and coupled formulations. The selected numerical model is an extended one-dimensional compliant area-flow system with variable-radius corrections. Its implementation is assessed through self-convergence, backend agreement, closure-health checks, and reproducibility records. A preliminary comparison at \(t=1.0\) s evaluates the 1D solution against two resolved 3D velocity datasets representing 23% and 40% radius reductions. Under the reported node-slab observation operator, the mean absolute axial-velocity discrepancies are 7.47 and 9.44 cm/s, with maxima of 26.26 and 47.48 cm/s. The largest differences occur near and downstream of the stenosis, where the 1D model overpredicts velocity. Because the comparison uses node-based sampling and incomplete archived 3D diagnostics, it is interpreted as a mismatch-localization study rather than validation. The report concludes by identifying the matched quadrature, boundary, pressure, and provenance data required for a stronger comparison.

Revise the numerical values if the 3D operator is recomputed.

## 1.7 Rewrite the conclusion around answers, not recap

The current conclusion accurately repeats limitations but largely restates prior sections. A stronger conclusion should answer the research questions:

- what was defined;
- what was numerically verified;
- what the comparison showed;
- what remains unresolved;
- which next experiment is decisive.

A proposed conclusion appears later in this review.

## 1.8 Style and terminology

Replace software-contract language where ordinary scientific prose is clearer.

Examples:

- “fixes the vocabulary” → “defines the model and output conventions”;
- “bounded numerical record” → “scope-limited numerical study”;
- “CLI surfaces” → “command-line implementations”;
- “admitted descriptor values” → “implemented options”;
- “model-record data” → “case parameters”;
- “resolved-3D validation” → “agreement with a resolved 3D computational dataset”;
- “blood-dynamics setting” → “continuum hemodynamic setting”;
- “package-benchmark” → “package benchmark.”

Use “validation” only for comparison against experimental or clinical reality. Use “verification,” “cross-model comparison,” or “diagnostic agreement” elsewhere.

---

# 2. Numerical experiment

## 2.1 What the current experiment does establish

The current study establishes that:

- the 1D and 3D velocity datasets can be placed in a common axial/radial plotting framework;
- the largest discrepancies occur near and downstream of the stenosis;
- the 40% case shows larger maximum errors than the 23% case;
- the assumed 1D radial profile is a poor representation of parts of the resolved field;
- the current comparison is insufficient for pressure, clinical, or general 3D-accuracy claims.

These are useful findings. They should be presented as the result, not buried beneath defensive wording.

## 2.2 The current “section mean” is not a physical section average

The manuscript averages node-centered axial velocities over thin slabs. That statistic is

\[
\widetilde u_{\mathrm{node}}(z_j)
= \frac{1}{N_j}\sum_{n\in\mathcal N_j} u_z(x_n),
\]

not the physical cross-sectional mean

\[
\overline u_{3D}(z)
= \frac{1}{|S(z)|}\int_{S(z)}u_z\,dS.
\]

These quantities coincide only under restrictive sampling conditions. Tetrahedral nodes are generally not uniformly distributed in area, and local refinement can bias an arithmetic node mean.

Figure 9 visibly contains regular sawtooth oscillations in nominally uniform upstream and downstream regions. This pattern may reflect mesh-layer or slab-sampling aliasing rather than physical oscillation. The operator should be recomputed before the plot is used to interpret detailed axial structure.

### Preferred revision

Intersect the tetrahedral field with each cross-sectional plane, interpolate the finite-element velocity, and evaluate an area quadrature. Then compute:

- area;
- volumetric flow;
- area-mean axial velocity;
- optional standard deviation or profile residual.

### Minimum revision if quadrature is unavailable

Rename every instance of “section mean” as **node-slab arithmetic mean**. Add the formula, node-count weighting, slab width, and a sensitivity study over at least three slab widths. Do not interpret the sawtooth structure as physics.

## 2.3 Match geometry, wall model, boundary data, and initial state

A valid 1D/3D comparison needs a case-matching table. The manuscript currently provides paths, times, node counts, and two severities, but not a complete matching record.

Add the following for both models:

- reference radius or area profile;
- throat position and minimum radius;
- stenosis definition: radius reduction versus area reduction;
- wall treatment: fixed, prescribed, 1D compliant, or resolved FSI;
- density and viscosity;
- inlet profile and time dependence;
- outlet pressure, traction, area, or impedance;
- initial condition and any inflow ramp;
- final time and sampling time;
- 3D element order, element count, and time step;
- 1D grid, time step, limiter, and wall parameters.

The 3D wall model is particularly important. If the resolved data are fixed-wall while the 1D model is compliant, either:

1. compare against a rigid/frozen-area 1D case, or
2. report the 1D area change and quantify the wall-model mismatch.

## 2.4 Address the transient nature of the comparison

The 1D run begins from \(Q=0\) and immediately imposes a positive inlet flow. This is a startup-wave problem, not automatically a steady stenosis problem.

Figure 9 contains a pronounced negative excursion of the 40% 1D curve immediately upstream of the throat. The manuscript does not explain whether this is:

- physical transient flow reversal;
- a reflected characteristic wave;
- source-term imbalance;
- interpolation behavior;
- or a plotting/data error.

Add:

- time histories at inlet, pre-throat, throat, and outlet;
- minimum and maximum flow over space and time;
- wave-travel or settling-time discussion;
- a statement of whether \(t=1\) s is transient, periodic, or quasi-steady;
- a comparison using matched inflow ramps if the 3D data used one.

If the goal is steady comparison, solve or demonstrate convergence to a steady state rather than selecting one transient snapshot.

## 2.5 Define every discrepancy metric

The symbols \(e_s\), \(e_r\), “Mean rel.,” and “Max rel.” are not formally defined in the numerical section.

Add explicit formulas. For axial targets \(z_j\),

\[
e_s(z_j)=\overline u_{1D}(z_j)-\overline u_{3D}(z_j),
\]

\[
\mathrm{MAE}_s=\frac{1}{J}\sum_{j=1}^{J}|e_s(z_j)|,
\qquad
\mathrm{RMSE}_s=
\left(\frac{1}{J}\sum_{j=1}^{J}e_s(z_j)^2\right)^{1/2}.
\]

Prefer a global relative norm,

\[
E_{2,\mathrm{rel}}
=
\frac{
\left(\sum_j w_j e_s(z_j)^2\right)^{1/2}
}{
\left(\sum_j w_j \overline u_{3D}(z_j)^2\right)^{1/2}
},
\]

over pointwise relative error. Pointwise ratios are unstable near zero and can dominate maxima.

For radial bins, weight discrepancies by annular area. Equal weighting of populated bins gives the same influence to bins with very different physical area and node counts.

## 2.6 Report sampling uncertainty and occupancy

For each node slab or radial bin, report:

- number of nodes;
- standard deviation of \(u_z\);
- standard error or a descriptive spread;
- empty-bin handling;
- minimum occupancy threshold.

Use uncertainty bands or error bars in Figure 10. A radial-bin mean based on a small or nonuniform node sample should not be plotted with the same visual authority as a densely sampled bin.

## 2.7 Compare flow before reconstructed profile shape

The most natural reduced variable is flow. A stronger comparison sequence is:

1. geometry or area profile;
2. \(Q_{1D}(z,t)\) versus \(Q_{3D}(z,t)=\int_{S(z)}u_z\,dS\);
3. mean velocity;
4. radial profile;
5. pressure, when available.

The current analysis jumps directly to velocity, even though node averages cannot verify flow conservation. A quadrature-based flow comparison would separate disagreement in total transport from disagreement in profile shape.

## 2.8 Add a complete physical and numerical parameter table

The manuscript lists \(L\), \(N\), \(\Delta z\), \(\Delta t_{\max}\), CFL cap, viscosity, and some geometry parameters, but omits enough parameters that the run cannot be reconstructed from the manuscript alone.

Add values and units for:

- density \(\rho\);
- healthy radius \(R_{\max}\) or \(R_{\mathrm{base}}\);
- Young’s modulus \(E\);
- wall thickness \(h\);
- Poisson ratio \(\sigma\);
- \(K=Eh/(1-\sigma^2)\);
- wall-law coefficient \(\beta\);
- external pressure;
- positivity floor;
- source-difference stencil;
- limiter parameter;
- all non-Newtonian parameters used in Figure 13;
- shear-rate regularization and viscosity bounds;
- inlet ramp or waveform;
- outlet reference pressure or area.

A machine-readable manifest is valuable, but the principal case must also be readable in the manuscript.

## 2.9 Reassess the radial-profile comparison

Figure 10 compares reconstructed 1D profile curves with radial-bin node means. Strengthen it by:

- using local current radius or explicitly justifying \(R_0(z)\);
- stating bin edges and evaluation points;
- showing annular area weighting;
- reporting node count per bin;
- plotting 3D variability;
- separating the three axial stations by line style as well as color;
- moving the legend away from the x-axis label;
- avoiding a single error summary that equally weights all populated bins.

The current result is still useful: it shows that a fixed parabolic closure cannot represent all local resolved profiles. Frame the conclusion around that closure limitation rather than general 1D failure.

## 2.10 Expand cases only after fixing the operator

Additional severities and times would improve generality, but they are lower priority than correcting the observation operator and matching the cases.

The minimum strong study is:

- the existing 23% and 40% cases;
- multiple time points or a demonstrated steady state;
- correct area quadrature;
- complete case matching;
- defined error norms;
- sensitivity to one closure choice.

A larger design could add 50% severity. Treat the 73% package case as an internal stress test unless it has independently matched resolved data and physical-admissibility checks.

## 2.11 Separate software benchmark from scientific experiment

Section 2.1 currently sits under the resolved-velocity section, although it evaluates a different evidence class. Move it before the 3D comparison and rename it **Verification and Reproducibility**.

The scientific sequence should be:

1. model;
2. discretization;
3. verification;
4. cross-model comparison;
5. interpretation.

## 2.12 Define benchmark “OK” criteria

Table 5 reports 252 rows as “OK,” but no reader-facing thresholds are given. Add a compact criteria table.

Examples:

- finite values;
- positive area;
- maximum CFL below threshold;
- mass-conservation tolerance;
- expected observed-order interval;
- backend relative-difference tolerance;
- maximum permitted reflected-wave metric;
- MPS/CPU comparison tolerance.

“Execution completed” and “scientific result passed” must be different statuses.

## 2.13 Strengthen numerical verification

Self-convergence is useful but cannot show convergence to the correct equation. Add at least one independent target:

- exact preservation of a zero-flow rest state;
- an analytic uniform-tube wave problem;
- a manufactured solution with source terms;
- an independent implementation for a simplified case.

For the geometry-rest test, report:

- \(\max|a-a_0|\);
- \(\max|Q|\);
- mass defect;
- source-flux imbalance;
- positivity-projection activations.

## 2.14 Explain observed convergence orders

Figure 11 should state:

- the self-convergence formula;
- refinement ratios;
- error norm;
- reference grid or successive-grid comparison;
- time-step scaling;
- interpolation between grids;
- expected order for each method;
- reason for order reduction near boundaries, sources, limiters, or time integration.

The current median-and-range summary can remain, but it should not replace the underlying table.

## 2.15 Define backend parity metrics

Figure 12 uses “Max final-state L2 difference” and an “aggregate difference,” but the manuscript does not define:

- whether area and flow are normalized;
- how quantities with different units are combined;
- whether the maximum is over fields, cases, or cells;
- whether the native solution is a reference or simply another realization.

Use separate dimensionless relative norms for area and flow, or nondimensionalize the state before aggregation.

The SciML comparison changes the time integrator while retaining the same spatial operator. It tests time-integration agreement, not independent solver parity.

## 2.16 Improve performance reporting

If runtime remains in the main text, report:

- hardware model;
- CPU/GPU/MPS device;
- thread count;
- warm-up and compilation policy;
- number of repetitions;
- median and spread;
- whether transfer time is included;
- separate CPU and MPS times.

Figure 15 currently shows a combined “compare elapsed” quantity rather than a transparent CPU-versus-MPS speed comparison. Either revise the plot or move it to the software supplement.

---

# 3. Mathematical rigor

## 3.1 Correct the strict-hyperbolicity statement

For the homogeneous flux

\[
F(A,Q)=
\begin{pmatrix}
Q\\
\alpha Q^2/A+\Psi(A)
\end{pmatrix},
\]

with \(u=Q/A\) and \(c^2=(A/\rho)\partial_A p_g\), the eigenvalues are

\[
\lambda_\pm
=
\alpha u
\pm
\sqrt{c^2+\alpha(\alpha-1)u^2}.
\]

The manuscript states that \(c^2>0\) implies strict hyperbolicity. That conclusion is automatic when \(\alpha\ge 1\), but not for a general \(0<\alpha<1\). In the latter case the radicand can become nonpositive.

Revise the result to state the pointwise condition

\[
c^2+\alpha(\alpha-1)u^2>0.
\]

For the implemented variable coefficient

\[
\alpha_{\mathrm{eff}}(z)
=
\alpha_P+\alpha_c(R_0'(z)),
\]

report:

- \(\min_z\alpha_{\mathrm{eff}}\);
- \(\max_z\alpha_{\mathrm{eff}}\);
- the minimum characteristic radicand over every run;
- any hyperbolicity guard in the implementation.

## 3.2 Qualify the boundary Riemann invariants

Appendix G uses

\[
w_\pm=u\pm 4c_0a^{1/4}.
\]

These are the standard invariants for the homogeneous reference system with \(\alpha=1\) and \(c=c_0a^{1/4}\). The reported interior model uses a parabolic momentum factor \(\alpha_P=4/3\) plus a variable-radius correction.

Therefore, one of the following must be done:

1. derive the exact characteristic boundary relation for the implemented \(\alpha_{\mathrm{eff}}\);
2. solve the incoming characteristic condition numerically using the actual left eigenvector;
3. explicitly label the current formula as an \(\alpha=1\) boundary approximation and quantify reflected-wave sensitivity.

Do not call the displayed expressions exact Riemann invariants for the full implemented system unless that derivation is supplied.

## 3.3 Bridge the physical wall law to the solver flux

The main model uses physical area \(A\), pressure law \(\beta\), and elastic potential \(\Psi\). Appendix G switches to \(a=R^2\), \(K=Eh/(1-\sigma^2)\), and a flux term proportional to \(a^{3/2}\).

Add a derivation showing:

- \(A_{\mathrm{phys}}=\pi a\);
- \(Q_{\mathrm{phys}}=\pi q\);
- the solver pressure law;
- the relationship between \(K\), \(\beta\), \(R_{\max}\), and \(A_0\);
- the transformed elastic potential;
- the transformed geometry source;
- the transformed friction term.

This derivation is necessary to demonstrate that the implemented operator realizes the stated physical model.

## 3.4 State the extended Canic model in the main methods section

The main area-flow equations describe a conventional compliant 1D system. The experiment, however, uses:

- \(\alpha_c(R_0')\);
- \(\alpha_c'(z)\);
- \(R_0'\) and \(R_0''\) terms;
- a \(p_2\) correction.

These terms define the actual selected model and should not appear only as implementation detail in Appendix G.

Add a boxed equation for the full extended system, identify which terms vanish in the classical baseline, and explain the asymptotic or modelling origin of each correction.

## 3.5 Define every implementation parameter and correction term

The following are used without adequate reader-facing definition:

- \(E\);
- \(h\);
- \(\sigma\);
- \(K\);
- \(R_{\max}\);
- \(p_2\);
- the discrete derivative in \(\partial_z^d p_2\);
- the positivity floor;
- limiter slopes;
- reconstruction states.

Every symbol in the numerical operator must appear in the notation table and parameter table.

## 3.6 Resolve the MUSCL/first-order inconsistency

Section 2 states that the experiment uses MUSCL finite volume with a minmod limiter. Appendix G.2 says the interface flux uses “neighboring first-order states.”

Revise Appendix G to give the actual reconstruction:

- cell slopes;
- minmod definition;
- left and right interface states;
- positivity treatment after reconstruction;
- boundary reconstruction;
- source evaluation order.

If Appendix G intentionally presents the first-order scheme, label it as such and add a separate MUSCL subsection.

## 3.7 Define and audit the positivity projection

The SSPRK3 stages apply a projection \(\Pi\), but \(\Pi\) is not fully defined.

State:

- the area floor;
- whether only \(a\) or both \(a\) and \(Q\) change;
- whether conservation is lost;
- whether the projection is applied before flux evaluation;
- activation count per run;
- effect on convergence order.

Third-order SSPRK accuracy can only be interpreted straightforwardly when the nonlinear projection is inactive or its effect is controlled.

## 3.8 Explain flux-source consistency and well balancing

The flux depends explicitly on geometry, and the source includes geometry derivatives and an \(\alpha_c'\) term. Add a derivation showing why the chosen flux/source split recovers the intended continuous equation.

Then state whether the discretization is:

- exactly well balanced;
- approximately well balanced;
- or not designed to preserve rest.

The geometry-rest benchmark should quantify this property.

## 3.9 Clarify the outlet condition

The general model section says the numerical study uses prescribed inlet flow and outlet gauge pressure. The implementation section fixes \(a_{\mathrm{out}}=R_0(L)^2\) and obtains ghost flow from an outgoing characteristic relation.

Explain explicitly that, under the selected wall law and external-pressure convention, setting \(a_{\mathrm{out}}=a_0(L)\) corresponds to a particular outlet gauge pressure. State the equivalence and its assumptions.

## 3.10 Separate wall mechanics from multiscale coupling

The current wall/FSI descriptor includes a “multiscale” option. Multiscale coupling is not a wall law in the same sense as rigid, elastic-1D, or resolved FSI mechanics.

Use separate axes:

- wall model \(\mathcal W\): rigid, reduced elastic, resolved FSI;
- coupling model \(\mathcal C\): isolated vessel, 0D outlet, 1D network, 3D-1D coupling.

This improves conceptual rigor and avoids implying that an interface condition is a wall closure.

## 3.11 Supply non-Newtonian parameters or reduce the claim

Figure 13 compares Newtonian, Carreau, Carreau-Yasuda, Casson, and power-law descriptors, but the manuscript does not present the parameter values needed to interpret the bars.

Add a table of:

- zero- and infinite-shear viscosities;
- time constants;
- exponents;
- yield stress;
- power-law consistency;
- regularization;
- viscosity clipping bounds.

If those runs are only descriptor health checks, relabel the figure accordingly and move it to the supplement. Do not present it as a physical rheology sensitivity study without a parameter rationale.

## 3.12 Use verification and validation terminology consistently

Recommended terminology:

- **code verification:** tests against exact/manufactured results;
- **solution verification:** discretization and iterative error;
- **cross-model comparison:** 1D versus 3D computation;
- **validation:** comparison against experiment or clinical measurement;
- **reproducibility:** ability to regenerate results;
- **software health:** tests, smoke runs, and interface checks.

This vocabulary will make the evidence hierarchy more precise than repeated use of “not validation.”

## 3.13 Tighten theorem assumptions without overloading the main text

The continuum results can remain classical, but each theorem should either:

- state the necessary regularity and domain hypotheses directly; or
- cite a standing assumption and avoid repeating proof-level detail.

The report does not need a full introductory functional-analysis chapter unless those spaces are used in an original theorem or weak formulation. Appendix D can be substantially shortened.

---

# 4. Labels and notation

## 4.1 Adopt a non-overloaded symbol map

| Current use | Recommended use | Purpose |
|---|---|---|
| \(A\), stored A | \(A\), \(a\) | Area vs radius squared |
| \(Q\), scaled Q | \(Q\), \(q\) | Physical vs scaled flow |
| \(R\), rheology R | \(R\), \(\mathcal R\) | Radius vs descriptor |
| \(W\), multiscale W | \(\mathcal W\), \(\mathcal C\) | Wall vs coupling |
| \(T\), final time | \(\mathbf T\), \(t_f\) | Stress vs terminal time |
| \(F_t\), flux F | \(\mathbf F_{\rm def}\), \(\mathcal F\) | Deformation vs flux |
| profile P, pressure p | \(\mathcal P\), \(p\) | Profile vs pressure |
| case 77, case 60 | C23, C40 | Severity-first labels |

Use \(q=Q_{\mathrm{phys}}/\pi\) in the solver derivation. Then

\[
u_{\mathrm{avg}}
=
\frac{Q_{\mathrm{phys}}}{A_{\mathrm{phys}}}
=
\frac{q}{a}.
\]

This removes the repeated warning that stored \(Q\) is not physical flow.

## 4.2 Reserve formal environments for formal content

Use:

- **Definition** for mathematical objects;
- **Assumption** for modelling hypotheses;
- **Proposition/Theorem** for derived mathematical claims;
- **Convention** for units, signs, or output choices;
- **Implementation note** for code identifiers and storage;
- **Remark** only when it adds interpretation.

Code names such as `canic-extended-1d` and `classical-1d-no-slip` should be in a model table, not elevated to mathematical definitions.

## 4.3 Rename observation quantities accurately

Use:

- “node-slab mean” for the current arithmetic node statistic;
- “cross-sectional mean” only for area quadrature;
- “radial-bin node mean” for the current radial statistic;
- “resolved computational dataset” instead of “3D truth”;
- “comparison error” rather than “model accuracy” unless matching is complete.

## 4.4 Define case identifiers once

At the start of the comparison section, add a table:

| Label | Source ID | Radius reduction | Time |
|---|---:|---:|---:|
| C23 | 77 | 23% | 0.9995 s |
| C40 | 60 | 40% | 0.9995 s |

Use C23 and C40 in figures and prose. Preserve source IDs in the provenance table only.

## 4.5 Remove unused acronyms and future notation

The acronym and notation appendices contain terms not used in the report, including several clinical imaging acronyms, beats per minute, finite-difference method, Womersley number, and passive-scalar/Peclet notation.

Remove unused entries. A final thesis should document the work actually presented, not reserve symbols for possible future extensions.

## 4.6 Standardize equation and figure references

Use “Equation (1.2)” consistently, not a mix of “Eq. 1.2,” “the equation above,” and definition-only references.

Every result paragraph should refer directly to the relevant figure or table. Every figure caption should identify:

- quantity;
- operator;
- case;
- time;
- units;
- line/marker meaning.

Keep the central caveat in the section text rather than repeating a long negative list in each caption.

---

# 5. Supplemental enhancements

## 5.1 Add a literature synthesis table

The manuscript explains model tiers conceptually but provides limited synthesis of individual studies. Add a concise literature table with:

- reference;
- dimension/model;
- wall treatment;
- rheology;
- stenosis type;
- comparison data;
- key limitation.

This will make the document function more clearly as a literature review and allow several pages of repetitive hierarchy prose to be shortened.

## 5.2 Add a model-case manifest

Create one human-readable table for the principal numerical cases and one machine-readable JSON/TOML/YAML manifest.

The human-readable table belongs in the main text. The machine-readable manifest belongs in the repository or supplement.

## 5.3 Archive the raw 3D inputs

Hashes prove identity only when the corresponding files are available. Archive:

- XDMF;
- HDF5;
- geometry metadata;
- time metadata;
- extraction script;
- license/source information.

Use an institutional repository, release archive, or DOI-bearing data deposit. If redistribution is not permitted, provide an automated acquisition script and immutable upstream identifiers.

## 5.4 Move hash inventories out of the main PDF

Appendix H devotes several pages to SHA-256 tables. Keep:

- repository tag or commit;
- environment versions;
- archive DOI or release;
- one manifest hash;
- regeneration command.

Move per-file hashes to a machine-readable manifest. This preserves reproducibility while improving readability.

## 5.5 Add a list of figures and tables

The report contains fifteen figures and five tables. A list of figures and list of tables would improve navigation, especially if the document remains near its current length.

## 5.6 Rationalize the appendices

Recommended appendices:

- A. Symbols and acronyms actually used;
- B. Continuum derivations;
- C. Extended 1D model derivation;
- D. Numerical discretization and boundary treatment;
- E. Reproducibility and data manifest.

Move basic function-space material, unused scalar-transport notation, and full hash inventories to a separate supplement.

## 5.7 Improve figure design

Specific figure revisions:

- **Figure 1:** enlarge the 3D mesh or use a clearer orthographic view.
- **Figure 5:** increase vertical size and show one cross-sectional slice or zoom near the throat.
- **Figure 9:** add an error panel; explain the negative 1D excursion; remove sampling sawtooth through better quadrature.
- **Figure 10:** move the legend; add variability/occupancy; use line style plus color.
- **Figure 11:** add expected-order reference labels.
- **Figure 12:** define and nondimensionalize the difference metric.
- **Figure 13:** plot relative change from Newtonian or separate profile and rheology effects; identify 73% as stress test.
- **Figure 14:** reconcile its values/configuration with Table 2.
- **Figure 15:** show CPU and MPS times separately, or move to supplement.

The current page layout leaves substantial unused space on page 32 and crowds two figures onto page 33. Rebalance the floats.

## 5.8 Audit the references

Before submission:

- verify DOI metadata and page ranges;
- check whether preprints have later versions or journal publications;
- standardize capitalization and journal names;
- remove editorial comments from bibliography entries;
- add literature where current 2D/FSI and validation coverage is thin;
- distinguish sources used for derivation from sources used for empirical evidence.

---

# 6. Section-by-section final edit map

## Abstract, page 1

- Replace convention-heavy summary with motivation, method, quantitative result, and limitation.
- Write \(t=1.0\) s, not \(T=1\).
- State 23% and 40% cases.
- Report the principal errors.
- Avoid “CLI surfaces” and “bounded parts.”

## Introduction, pages 4-5

- Move anatomy-function motivation to the opening.
- Add research questions and contributions.
- Add the claim-evidence boundary.
- Move Figure 1 after the contribution paragraph.
- Replace “hierarchy of the single-vessel hemodynamic models” with “hierarchy of single-vessel hemodynamic models.”
- Replace “idealized \((C^\infty)\) model of stenosed vessels” with “smooth idealized stenosis geometry.”

## Continuum foundations, pages 5-11

- Reduce by approximately one-third to one-half.
- Keep physical assumptions and governing equations.
- Move proof detail and full rheology catalog to appendices.
- Retain a short Newtonian versus generalized-Newtonian discussion.
- Remove implementation descriptor names from this section.

## Governing equations and selected model, pages 11-19

- Add a compact assumption box.
- State the physical 1D model.
- Add the physical-to-solver map.
- Add the full extended model used in Section 2.
- Correct the hyperbolicity statement.
- Separate wall and coupling descriptors.
- Define the exact outlet-pressure/area equivalence.

## Model hierarchy, pages 19-23

- Replace repetitive prose with one comparison table and shorter interpretation.
- Preserve the important statement that fidelity is not a validation rank.
- Add a literature synthesis rather than only conceptual descriptions.

## Clinical pressure-flow motivation, pages 23-25

- Move a concise version to the introduction.
- Keep detailed output conventions in the appendix.
- Retain Figures 7-8 only if pressure remains a central future objective.
- Do not let pressure occupy more space than the completed velocity study.

## Resolved-velocity comparison, pages 26-29

- Rename as “Preliminary cross-model velocity comparison.”
- Add a model/data matching table.
- Replace the long setup paragraph with parameter and operator tables.
- Recompute physical cross-sectional integrals.
- Define errors and weights.
- Add time-history and operator-sensitivity checks.
- Explain the negative pre-throat excursion.
- Reconcile Figure 14 with Tables 2-4.

## Package benchmark, pages 29-33

- Move before the 3D comparison.
- Rename as verification and reproducibility.
- Define “OK” thresholds.
- Add exact/manufactured verification.
- Define observed-order and backend metrics.
- Move environment-specific runtime plots to supplement unless central.

## Conclusions, page 34

- Answer the research questions explicitly.
- State one central result and one central limitation.
- Identify the next decisive experiment.
- Remove repeated lists of what was not established.

## Acronyms and notation, pages 35-46

- Consolidate.
- Remove unused/future symbols.
- Resolve symbol overloading.
- Add missing solver symbols and parameter values.
- Keep physical and numerical unit systems in one clear conversion table.

## Mathematical and numerical appendices, pages 47-61

- Retain derivations directly supporting the selected model.
- Correct hyperbolicity and boundary-characteristic statements.
- Add actual MUSCL reconstruction.
- Define positivity projection and \(p_2\).
- State well-balancing and conservation properties.

## Code availability, pages 62-65

- Replace per-file hash tables with one manifest reference.
- Add public or institutional archive information.
- Record exact release/tag, clean/dirty status, and environment.
- Keep commands concise.

## References, pages 66-68

- Verify current versions and metadata.
- Standardize formatting.
- Expand the literature-review coverage where needed.

---

# 7. Proposed revised conclusion

> This report defined a consistent hierarchy for idealized stenotic blood-flow models and specified an extended one-dimensional area-flow realization with declared wall, rheology, boundary, numerical, and output conventions. Verification experiments documented self-convergence and implementation agreement for the reported metrics. Under the declared \(t=1.0\) s velocity observation operator, the 1D model reproduced the broad upstream and downstream flow trend in the 23% and 40% cases but overpredicted velocity near the stenosis. The largest discrepancies occurred near and downstream of the throat, with the stronger mismatch in the 40% case.
>
> The comparison does not isolate a unique source of error because the current 3D statistic is node based and the 1D and 3D wall, boundary, initial, and post-processing assumptions are not yet fully matched. The next decisive study is therefore not a broader parameter sweep. It is a matched comparison using archived 3D inputs, area-quadrature flow and mean-velocity operators, complete run diagnostics, and controlled variation of one modelling choice at a time. Pressure-drop and pressure-ratio studies should follow only after the pressure reference, observation maps, and external comparison data are specified.

---

# 8. Final revision sequence

## Stage 1: Scientific and mathematical corrections

1. Freeze the intended final scope.
2. Rename physical and solver variables.
3. Add the model-to-solver derivation.
4. correct hyperbolicity and boundary-characteristic statements.
5. Define the MUSCL operator and positivity projection.
6. Add full physical/numerical parameters.
7. Define errors and benchmark thresholds.

## Stage 2: Recompute or relabel the comparison

1. Restore the raw 3D data.
2. Match geometry and boundary metadata.
3. Implement area quadrature.
4. Add flow and mean-velocity outputs.
5. test slab/operator sensitivity.
6. inspect time histories and flow reversal.
7. regenerate Tables 2-4 and Figures 9-10.
8. reconcile Figure 14.

## Stage 3: Restructure the manuscript

1. Rewrite abstract and introduction.
2. Move verification ahead of cross-model comparison.
3. Compress continuum derivations.
4. Replace hierarchy repetition with tables.
5. shorten clinical pressure discussion.
6. rewrite conclusion.

## Stage 4: Presentation and reproducibility

1. Consolidate notation and acronyms.
2. improve figure readability.
3. move hashes to a manifest.
4. add release/archive information.
5. audit references.
6. run a final cross-reference and unit check.

---

# 9. Final acceptance checklist

## Scientific claims

- [ ] Every claim has a matching evidence class.
- [ ] “Validation” is reserved for experimental or clinical comparison.
- [ ] Pressure and FFR are clearly motivation or completed outputs, not both.
- [ ] 3D data are described as a computational comparison dataset.

## Numerical experiment

- [ ] Geometry, wall, rheology, inlet, outlet, initial state, and time are matched or explicitly unmatched.
- [ ] 3D mean velocity is area integrated, or the statistic is renamed.
- [ ] Flow is compared before profile reconstruction.
- [ ] Error formulas, weights, norms, and units are defined.
- [ ] Sampling occupancy and variability are reported.
- [ ] Negative or oscillatory features are explained.
- [ ] Raw inputs and run diagnostics are archived.

## Mathematical rigor

- [ ] Hyperbolicity condition is correct for the stated alpha range.
- [ ] Boundary invariants match the implemented system or are labelled approximate.
- [ ] Physical-to-solver transformation is derived.
- [ ] Extended variable-radius equations are stated.
- [ ] MUSCL reconstruction is documented.
- [ ] Positivity projection is defined and activation counts are reported.
- [ ] All source terms and parameters are defined.
- [ ] Wall and multiscale coupling axes are separate.

## Labels and presentation

- [ ] \(A\)/\(a\), \(Q\)/\(q\), \(R\)/\(\mathcal R\), and \(T\)/\(t_f\) are unambiguous.
- [ ] Case labels include severity.
- [ ] Formal labels match content type.
- [ ] Unused acronyms and symbols are removed.
- [ ] Figures remain interpretable in grayscale.
- [ ] Captions state operators, time, cases, and units.
- [ ] Tables use readable font sizes.

## Reproducibility

- [ ] Principal parameters appear in the manuscript.
- [ ] Exact code release and environment are recorded.
- [ ] Benchmark pass/fail criteria are explicit.
- [ ] Runtime methodology is documented or moved to supplement.
- [ ] Hashes are available in a machine-readable manifest.
- [ ] The final archive contains the data required to reproduce every main figure.

## Overall recommendation

The report should be finalized as a **mathematical framework, numerical verification, and preliminary velocity-comparison study**. That framing is scientifically honest, technically substantial, and well supported by the existing work. The final manuscript will be materially stronger if it concentrates on that contribution rather than expanding its clinical claims.
