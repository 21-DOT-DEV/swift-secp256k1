---
description: Capture a single feature or chat session’s outcomes by reflecting on what happened, codifying lessons learned and best practices, and proposing actionable improvements—including edits to project artifacts and agent rules—based on the conversation and artifacts
auto_execution_mode: 1
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user‑supplied input before proceeding (if not empty). It may contain specific areas to focus on or additional artifacts to review (e.g., links to conversation transcripts or attachments).

## Purpose

This retrospective workflow aims to systematically inspect the work done during a **single feature/chat session**, consolidate lessons learned, and suggest concrete next steps.  It is **not** a generic sprint retrospective; instead, it digs into one session’s transcript, feature specification, planning artifacts and any other referenced materials to:

* Summarize the goals and outcomes of the session.
* Identify what went well and what caused friction.
* Surface patterns, decisions and rationales worth codifying as guidelines or rules.
* Detect gaps in understanding, missing documentation or ambiguous areas that merit clarification or future work.
* Recommend updates to project files (e.g., `spec.md`, `plan.md`, `tasks.md`, `AGENTS.md`, `.windsurf/rules/*`, `Constitution.md`, documentation files) to capture these insights.
* Suggest experiments or process adjustments aligned with industry best practices.

Unlike a static post‑mortem, this retrospective is **interactive**.  Before writing the final report, the workflow engages the user to validate findings and contribute their own insights.  Specifically, it will:

* Present the user with a list of the issues and tasks extracted from the current session and ask which ones caused the most friction, while also providing an “Other” option for an open‑ended response.
* Offer automatically generated recommendations (industry best practices, suggested rule updates, documentation changes) based on the session’s issues and ask whether the user agrees with them or wishes to supply their own improvements.
* Capture the user’s feedback and preferences through targeted questions so that these insights can be integrated into the final report and proposed edits.

The end product is a structured report plus a set of actionable edits, ready for user review and potential integration into the project.

## Operating Constraints

* **Comprehensive, but finite**: Process exactly one session; do not spill over into unrelated features or prior cycles.  If the conversation references multiple distinct features, ask for clarification before proceeding.
* **Read all referenced artifacts**: Load any available transcripts (chat log), the active feature’s `spec.md`, any generated `plan.md` and `tasks.md`, and any other files explicitly mentioned by the user.  Use the minimal necessary context principle from `/speckit.analyze` to avoid overloading context.
* **Adhere to the project constitution** (`.specify/memory/constitution.md`): If suggestions conflict with principles, mark them as such.  Constitution‑violating changes require a separate process and **MUST NOT** be silently applied.
* **Propose edits, do not apply them automatically**: All suggested modifications to source files (including `AGENTS.md` and `.windsurf/rules/*`) must be grouped as “Proposed Edits.” Do not directly modify these files within this command; instead, present diffs or detailed change instructions for user approval.

* **Interactive feedback required**: Before composing the retrospective report, you **must** ask the user clarifying questions about which tasks/issues were most problematic and what improvements they advocate.  Only proceed to generate the report once all interactive questions have been answered or the user signals that no further input is needed.

## Retrospective Structure

Your output **must** follow this high‑level structure (use Markdown headings and bullet points as indicated):

1. **Session Overview**
   - One or two concise paragraphs summarizing the session’s goal, main activities, and final state (e.g., which tasks were completed, what features were implemented, or what discussions occurred).  Avoid quoting verbatim; summarize in your own words.
   - State the date/time (YYYY‑MM‑DD) and any relevant context (e.g., user persona, environment).

2. **Problems and Tasks Addressed**
   - A bullet‑point list describing specific problems tackled, tasks executed, or questions answered.  For each item, mention what artifact(s) it related to (e.g., spec section, code file, agent rule) and whether it was fully resolved or partially addressed.
   - If a bug or design flaw was uncovered, describe the symptoms, root cause (if known), and resolution.

3. **What Went Well (Strengths)**
   - Summarize successful strategies, decisions or implementations.  For example: clearly defined requirements, effective use of a pattern, rapid convergence on a design choice, high test coverage or efficient communication.  Relate each success to a broader best practice when possible (e.g., “Using a factory pattern simplified dependency management, an established best practice for decoupling modules.”).

4. **What Could Be Improved**
   - Identify areas of friction, mistakes, inefficiencies or miscommunications.  Categorize them (e.g., specification clarity, data modeling, UX considerations, testing gaps, tool usage, adherence to constitution).  For each, explain why it hindered progress and how it can be addressed going forward.
   - If you discover ambiguous decisions or gaps reminiscent of categories in `Clarify.md` (e.g., domain models, non‑functional requirements, edge cases), note them and recommend either a `/speckit.clarify` follow‑up or a direct specification update.

5. **Patterns, Decisions and Rationale**
   - Extract any significant patterns (architectural or behavioral) that emerged during the session (e.g., use of event‑driven architecture, consistent naming conventions, standardized error handling).  Cite the rationale if discussed and link to relevant best practices or industry standards.
   - Document key decisions made, including alternatives considered and why the chosen approach was preferred (similar to the pivot and decision clarification sections of the sprint retrospective in PR #1204).  Note whether these decisions should be added to `decisions.md` or captured as rules.

6. **Metrics and Indicators**
   - Provide qualitative and, if data permits, quantitative metrics to gauge session effectiveness.  Suggested metrics for single sessions include:
     * Number of tasks completed vs. deferred.
     * Coverage of spec requirements (percentage of categories addressed vs. outstanding).
     * Ratio of clarifications requested to clarifications needed (an indicator of specification quality).
     * Bug count or issues discovered.
     * Estimated time spent per task or per decision (if timestamps are available).
   - If precise numbers are unavailable, estimate qualitatively (e.g., “High,” “Medium,” “Low”).

7. **Knowledge Gaps & Follow‑Up**
   - List topics, tools or technologies where the session revealed insufficient knowledge.  Recommend research tasks, documentation updates or training to close these gaps.
   - Note any unclear requirements or open questions that should be clarified with stakeholders.

8. **Proposed Edits & Action Items**
   - Suggest concrete modifications to project artifacts (spec, plan, tasks, documentation, agent rules).  For each change:
     * Identify the target file(s) and line(s) or section(s) to be modified.
     * Provide a brief rationale referencing insights from the retrospective.
     * Supply a diff or explicit replacement text.  Use `apply_patch`‑style unified diff format when appropriate.
   - If new tasks need to be created (e.g., to implement improvements), outline them with acceptance criteria and tie them back to the identified issues.
   - Group these edits by priority (e.g., Critical, High, Medium, Low) and indicate whether they are constitutionally mandated, recommended, or optional.

9. **Experiments & Best Practices to Try**
   - Propose 1–3 experiments or process changes based on recognized best practices for the project domain.  Examples: adopting pair programming for complex modules, introducing automated linters, enhancing error logging, or revising rules in `.windsurf/rules/*` for clarity or safety.
   - Explain the expected benefit and how success should be measured.

10. **Team Health & Communication (Optional)**
   - If the session surfaced interpersonal or process issues (e.g., unclear communication between the user and assistant, conflicting interpretations of the spec), briefly describe them and propose ways to improve collaboration.  Otherwise, omit this section.

## Execution Steps

Follow these steps to create the retrospective:

1. **Initialize Context**
   - Ensure that `check-prerequisites.sh --json --paths-only` has been run and parse `FEATURE_DIR`, `FEATURE_SPEC`, `PLAN`, and `TASKS` if they exist (as described in `/speckit.analyze`).  Abort if the active feature directory or spec is missing.
   - Collect the full chat transcript for the session (provided by the user) and any attachments.  Normalize timestamps to the user’s timezone.

2. **Load Artifacts**
   - From the feature directory, load `spec.md`, `plan.md`, `tasks.md` and any previously generated analysis reports or clarifications.  Use the progressive disclosure technique to read only necessary parts.
   - In parallel, load `AGENTS.md` and `.windsurf/rules/*` if suggestions may affect agent instructions or rules.  Do not modify them yet.

3. **Analyze the Session**
   - Review the transcript and artifacts to reconstruct what was attempted and achieved.
   - Identify successes, problems, decisions, patterns and knowledge gaps.  Cross‑reference them with categories from the clarification taxonomy (Functional, Domain & Data Model, Interaction & UX, Non‑Functional, Integration & External, Edge Cases, Constraints, Terminology, Completion, Misc) to ensure broad coverage.
   - When recognizing a gap that fits one of these categories but remained unresolved, note it under “What Could Be Improved” and label it as a candidate for clarification or further research.

4. **Gather User Feedback (Interactive)**

   **⚠️ MANDATORY GATE**: Before drafting the final report, you MUST complete this interactive sequence and receive user responses. Do NOT proceed to step 5 until all sub-steps are answered.

   This sequence should occur after you have performed your own initial analysis and extracted a list of issues/tasks from the session but **before** writing any report text.

   1. **Identify Issues for Confirmation** (Question 1):
      - Review the session transcript and artifacts to compile a concise list of the most significant problems or tasks encountered.
      - Present these to the user as a numbered list with an "Other" option for free‑form input.
      - Ask: "Which issue(s) caused the most friction?"
      - **STOP and wait for user response.**

   2. **Solicit Improvement Suggestions** (Question 2):
      - Based on the confirmed problems and industry best practices, generate 2-4 recommended improvements.
      - Present these recommendations and ask the user to confirm which ones should be included OR to supply their own improvement ideas.
      - Ask: "Do you agree with these recommendations, or would you like to suggest different improvements?"
      - **STOP and wait for user response.**

   3. **Final Check** (Question 3 - Optional):
      - Ask if there are any additional insights or preferences that should inform the retrospective.
      - Ask: "Any other issues or insights to include, or should I proceed with the report?"
      - **STOP and wait for user response OR explicit "proceed" signal.**

   4. Collect and validate all user answers before proceeding.

   **CHECKPOINT**: Only proceed to step 5 after receiving responses to questions 1-3 (or user signals to skip remaining questions).

5. **Compose the Retrospective Report**
   - Populate each section (1–10) with clear, concise text.  Use bullet points or tables when listing items.  Keep paragraphs short (≤3–5 sentences).  Avoid long narrative in tables: they are for keywords, phrases or numbers.
   - Where relevant, connect issues to industry standards or guidelines (e.g., OWASP for security concerns, 12‑Factor App for configuration management) and cite them.

6. **Formulate Proposed Edits**
   - For each insight that implies a change, draft the diff or descriptive instruction.  Ensure edits preserve existing file structure and heading hierarchy.  When updating agent instructions or rules, follow the patterns used in `AGENTS.md` and `.windsurf/rules/*` (e.g., rule syntax, comment conventions) and respect constitutional principles.
   - Flag any modifications requiring constitution updates (these must be deferred to a separate update process).

7. **Validate & Finalize**
   - Cross‑check that all categories of the retrospective structure have been considered.  If certain sections are empty (e.g., no metrics available), explicitly note “N/A” rather than omitting.
   - Confirm that proposed edits do not conflict with the constitution or existing rules; if they do, note the conflict and mark as “Requires Constitution Update.”
   - Present the final report and proposed edits to the user.  Include a short summary of next steps, such as “Review and apply high‑priority edits,” “Schedule a follow‑up clarification session,” or “Adopt experiment X and measure Y.”

## Behavioral Notes

* Be objective and factual; do not invent details absent from the transcript or artifacts.  Where information is missing, explicitly state it as a knowledge gap.
* Use simple, clear language.  Avoid jargon unless it is necessary and defined.
* Respect privacy and confidentiality: summarize the session without exposing sensitive data.
* When suggesting best practices or industry standards, provide a brief rationale tailored to the project context and user persona (e.g., maintainability, security, UX).

By following this retrospective prompt, you will generate a thorough debrief for a single feature/chat session and provide actionable guidance for continuous improvement at both the specification and agent‑rule level.