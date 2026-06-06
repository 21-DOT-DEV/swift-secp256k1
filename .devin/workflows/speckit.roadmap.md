---
description: Create or update the product roadmap from a natural language product description (multi-file index + per-phase roadmap)
auto_execution_mode: 1
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

You are creating or updating a user-facing **product roadmap** using a **multi-file structure** to keep LLM context small but the roadmap expressive.

- The **index file** lives at: `.specify/memory/roadmap.md`  
  This is a **high-level overview** only (vision, phase summaries, product-level metrics, compact change log).

- Detailed **phase files** live under: `.specify/memory/roadmap/`  
  Each phase gets its own markdown file, e.g.:  
  - `.specify/memory/roadmap/phase-1-foundation.md`  
  - `.specify/memory/roadmap/phase-2-build-infra.md`  
  - `.specify/memory/roadmap/phase-3-performance-delivery.md`  

**IMPORTANT:**  
- `roadmap.md` MUST remain **small and high-level**. It MUST NOT contain full feature specs.  
- Phase files are the **canonical source of detail** (feature descriptions, success metrics, dependencies).

Follow this execution flow:

1. **Detect existing artifacts (mode selection)**
   - If `.specify/memory/roadmap.md` does **not** exist: treat as **initial roadmap creation**.
   - If it exists: treat as an **incremental update**.
   - Phase files are stored under `.specify/memory/roadmap/`. If the folder or a phase file is missing, you MAY create it when needed.

2. **Gather context (if present)**
   - Read `.specify/memory/constitution.md` for principles, guardrails, and constraints that should inform prioritization.
   - Read `README.md` (or top-level docs) for product positioning and target audience.
   - Prefer explicit user input from `$ARGUMENTS`; otherwise infer from context and document assumptions.

3. **Interpret the user request**
   - The user’s input describes the **product vision**, desired **feature areas**, and possibly specific phases or features to add/update.
   - If the input clearly targets a specific phase (e.g., “update Phase 2 – build infra…”), focus changes on that phase file and keep the index in sync at a summary level.
   - If no phase is specified and no index exists, design a reasonable **phased roadmap** (Phase 1/2/3, MVP / v1 / v2, etc.).

4. **Storage model (MUST follow this)**
   - `.specify/memory/roadmap.md`:
     - Vision & Goals
     - Phases Overview (table of phases with name, status, file path)
     - Product-Level Metrics & Success Criteria
     - Global Risks & Assumptions (optional)
     - Global Change Log
   - `.specify/memory/roadmap/phase-*.md`:
     - Phase metadata (goal, status, last updated)
     - Detailed feature list (Name, Purpose, Metrics, Dependencies, Notes)
     - Phase-specific dependencies & sequencing
     - Phase-specific metrics
     - Phase-specific risks/assumptions
     - Optional phase-level notes/change log

5. **Generate feature entries (per phase, moderate detail)**
   For each feature/milestone, in its **phase file** include exactly these fields:

   - **Name** — concise, user-recognizable
   - **Purpose & user value** — the “why” in 1–2 sentences
   - **Success metrics** — measurable, user-facing outcomes (3–5 bullets)
   - **Dependencies** — other features or prerequisites
   - **(Optional) Notes** — constraints, policy, rollout or implementation considerations

   **DO NOT** copy full feature details into `roadmap.md`. Instead, summarize the phase in 1–3 bullets there.

6. **Phase creation & assignment**
   - On **initial creation**:
     - From the product description, derive 3–6 coherent phases (e.g., “Foundation & Discoverability”, “Performance & Delivery”, “Content & Accessibility”, “Advanced Features & Analytics”).  
     - For each phase:
       - Assign a numeric order (Phase 1, Phase 2, …).
       - Generate a phase file name like:  
         `.specify/memory/roadmap/phase-<N>-<kebab-case-short-name>.md`  
         Example: `phase-1-foundation-discoverability.md`
       - Populate that phase file with detailed features, dependencies, metrics, and risks for that phase.
   - On **incremental updates**:
     - If the user input references a **specific phase or feature**, update the corresponding phase file only.
     - If a feature moves between phases (e.g. active → backlog), update both affected phase files and adjust the summary in `roadmap.md` accordingly.
     - Avoid renaming phase files unless the goal changes significantly; if renamed, update the Phases Overview table in `roadmap.md`.

7. **Define product-level metrics & success criteria (index-level)**
   - In `roadmap.md`, choose 4–8 **product-level KPIs** tied to user value:
     - Activation, retention, satisfaction, conversion rate, support volume, etc.
   - These MUST be:
     - **User-facing**
     - **Technology-agnostic**
     - **Verifiable** without implementation details

8. **Derive dependencies & sequencing (phase-level detail, index-level summary)**
   - Within each phase file:
     - Document local dependencies and sequencing (“Feature A → Feature B → Feature C”) with brief rationale.
   - In `roadmap.md`:
     - Provide a **high-level dependency view** only (e.g., “Phase 1 foundation before Phase 2 infra,” “Token system blocks Dark Mode,” etc.).
     - Do NOT reproduce all detailed dependency graphs; link phases instead.

9. **Seed next steps for feature iteration**
   - For each phase, select 1–5 “next up” features and produce `/speckit.specify` hints.
   - These hints should generally appear in **console output**, not bloated into `roadmap.md`. You MAY add a small “Next Specs” list per phase if it stays concise.

   Example console hints:
   ```text
   Next: /speckit.specify "Feature: Search Functionality — instant client-side docs search using static index"
   Next: /speckit.specify "Feature: Utilities Library Extraction — dedicated Utilities library + CLI for sitemap tooling"
   ```

10. **Versioning & write output (index is versioned)**
    - The roadmap version is maintained **inside** `roadmap.md` header.
    - If creating a new roadmap index:
      - Set `Version: v1.0.0`
      - Set `Last Updated` to today.
      - Add a Change Log entry (“Initial roadmap created from product description”).
    - If updating an existing roadmap:
      - **Increment version** using semantic rules aligned with the constitution:
        - **MAJOR**: Backward-incompatible strategy shift or significant re-architecture of phases.
        - **MINOR**: New phase added, new major feature area introduced, or substantial reprioritization.
        - **PATCH**: Text clarifications, small status updates, minor adjustments that don’t change the roadmap’s intent.
      - Append a brief Change Log entry describing what changed and why (include bump type).
    - Write outputs:
      - Overwrite or create `.specify/memory/roadmap.md` (index, slim).  
      - Create or overwrite phase files under `.specify/memory/roadmap/` as needed (canonical detail).

11. **Validation before final output**
    - `roadmap.md` MUST contain:
      - Vision & Goals
      - Phases Overview table
      - Product-level Metrics & Success Criteria
      - (Optional) Global Risks & Assumptions
      - Change Log with semantic version bumps
    - Each phase file MUST contain:
      - Phase name/goal and status
      - At least one feature with Name, Purpose, Success metrics, Dependencies
      - Local dependencies and/or sequencing described
      - Phase-level metrics if applicable
    - `roadmap.md` MUST **NOT** include full feature specs (no long blocks duplicating phase file content).
    - If critical unknowns remain, include up to **3** `[NEEDS CLARIFICATION: …]` markers across the affected documents (index + phases combined). Prioritize by impact (scope > compliance/privacy > UX > technical).

12. **Report completion (console output)**
    - Show: roadmap version change, number of phases, total feature count.
    - Show: a short list of “Next `/speckit.specify` calls” (max 5, across the highest priority phase).

---

## Index & Phase Document Structure (use these Markdown scaffolds)

### 1. Index File: `.specify/memory/roadmap.md`

```markdown
# Product Roadmap

**Version:** vX.Y.Z  
**Last Updated:** YYYY-MM-DD

## Vision & Goals
- One-sentence product vision.
- Target users / personas.
- Top 3 outcomes (business/user).

## Phases Overview

| Phase | Name / Goal                         | Status      | File Path                                          |
|-------|-------------------------------------|-------------|----------------------------------------------------|
| 1     | Foundation & Discoverability        | COMPLETE    | roadmap/phase-1-foundation-discoverability.md      |
| 2     | Utilities Library & Build Infra     | NEXT UP     | roadmap/phase-2-utilities-build-infra.md           |
| 3     | Performance & Delivery Optimization | PLANNED     | roadmap/phase-3-performance-delivery.md            |
| 4     | Content & Accessibility             | PLANNED     | roadmap/phase-4-content-accessibility.md           |
| 5     | Future Features & Analytics         | FUTURE      | roadmap/phase-5-future-features-analytics.md       |

> Status suggestions: PLANNED, ACTIVE, COMPLETE, DEFERRED, FUTURE

## Product-Level Metrics & Success Criteria
- Activation rate reaches <X%> by <date or phase>.
- 7-day retention improves to <Y%>.
- NPS ≥ <Z>.
- Support tickets per active user ≤ <T>.
- Core Web Vitals within “Good” thresholds across all pages.

## High-Level Dependencies & Sequencing
- Phase 1 (Foundation) before Phase 2 (Utilities) — infra depends on sitemap foundation.
- Token System (Phase 3.x) blocks Dark Mode (Phase 4.x).
- Privacy Policy must ship before Analytics migration.
- Accessibility Audit should precede automated a11y testing in CI.

## Global Risks & Assumptions
- Assumptions: <bullets>
- Risks & mitigations: <bullets>

## Change Log
- vX.Y.Z (YYYY-MM-DD): <summary> — <bump type & rationale>
- vX.Y.(Z-1) (YYYY-MM-DD): <summary>
```

---

### 2. Phase File: `.specify/memory/roadmap/phase-<N>-<slug>.md`

```markdown
# Phase <N> — <Name / Goal>

**Status:** PLANNED | ACTIVE | COMPLETE | DEFERRED | FUTURE  
**Last Updated:** YYYY-MM-DD

## Goal
Short description of what this phase aims to accomplish and why it matters.

## Key Features

1. <Feature Name>
   - Purpose & user value: <1–2 sentences explaining the “why”>
   - Success metrics:
     - <metric 1>
     - <metric 2>
     - <metric 3>
   - Dependencies: <list of features, phases, or “none”>
   - Notes: <optional details, constraints, rollout, etc.>

2. <Feature Name>
   - Purpose & user value: ...
   - Success metrics:
     - ...
   - Dependencies: ...
   - Notes: ...

<!-- Add more features as needed -->

## Dependencies & Sequencing
- Local ordering: Feature A → Feature B → Feature C (with brief rationale).
- Cross-phase dependencies: <if any>.

## Phase-Specific Metrics & Success Criteria
- This phase is successful when:
  - <concrete, measurable outcomes tied to its features>

## Risks & Assumptions
- Assumptions: <bullets>
- Risks & mitigations: <bullets>

## Phase Notes / Change Log
- YYYY-MM-DD: <short note about reordering, adding/removing features, or status changes>
```

---

## General Guidelines

### Quick Guidelines
- Focus on **WHAT** users get and **WHY** it matters, not **HOW** it is implemented.
- Keep `roadmap.md` **slim** and **navigational**:
  - Use summaries and tables, not full specs.
- Keep phase files **focused per phase**:
  - One phase per file, with detailed features and metrics.
- Avoid implementation details (no frameworks, APIs, code internals) in roadmap documents.
- Ensure every high-priority feature is attached to a phase.

### Section Requirements

**Index (`roadmap.md`)** – MUST include:
- Vision & Goals
- Phases Overview table
- Product-level Metrics & Success Criteria
- High-level Dependencies & Sequencing
- Change Log

**Phase files (`roadmap/phase-*.md`)** – MUST include:
- Phase header with name, status, last updated
- Key Features with Name, Purpose, Metrics, Dependencies
- Phase-specific Dependencies & Sequencing
-