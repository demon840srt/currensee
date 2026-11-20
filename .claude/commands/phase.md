---
description: Run one build-plan phase — plan, implement, test, tick checklist. Never commits.
argument-hint: <phase-number>
---

Run **Phase $ARGUMENTS** from `docs/build-plan.md`.

1. **Load context.** Read `CLAUDE.md`, the Phase $ARGUMENTS section of `docs/build-plan.md`,
   and only the parts of `docs/SPEC.md`, `docs/ARCHITECTURE.md`, `docs/adr/` and
   `references/` that this phase needs. Confirm all earlier phases are ticked; if not, stop and say which.
2. **Plan mode.** Work in plan mode: no file edits yet. Present a short plan
   (files to create/change, tests to write first, risks, open questions) and **wait for my approval**.
3. **Implement.** After approval, write the tests first, then the code. Keep logic in
   `backend/CurrencyCore`; keep the app layer thin. Follow every rule in `CLAUDE.md`.
4. **Test.** Run `./scripts/test.sh`. If anything fails, fix it and re-run until green.
   Do not mark the phase done with failing or skipped tests.
5. **Tick the checklist.** In `docs/build-plan.md`, change `- [ ]` to `- [x]` only for items
   you actually verified. Leave unverifiable items (e.g. "looks right on a second display")
   unticked and list them under "Manual checks for you".
6. **Record decisions.** If you made a decision not in the SPEC, add an ADR in `docs/adr/`
   and one line in the SPEC decision log.
7. **Report.** Summarize: what changed (`git diff --stat`), test results, manual checks for me,
   and a proposed commit message.
8. **Do NOT commit or push.** Wait for my explicit "commit".
