# sales-insights — low March revenue (demo, defect on `main`)

A deliberately **defective** copy of the `sales-insights` sample data product, used to
drive the **data-ops (Fix)** agent's code-change → PR flow from Vibedata Studio.
The shipped defect lives on `main` (this IS the deployed product), so a Studio domain
bound here reads the bug directly; the agent investigates, opens its own fix branch, and
PRs the correction back. No real data, no secrets.

> Reproduces fully only when the warehouse the domain points at carries the matching
> (defective) source data — the code declares the defect; the symptom shows once that
> data is loaded. See the vd-data-engineering eval fixture `fabric-question-fix-oh` for the seed.
