# Git commit conventions

## Conventional Commits

Write every commit subject as `<type>[optional scope]: <description>`.

- Types: `feat`, `fix`, `refactor`, `test`, `style`, `docs`, `chore`, `perf`, `build`, `ci`
- Scope is optional and lowercase, naming the feature area (`oauth`, `report-actions`). Match the scope vocabulary already used in the repo's history; a bare `style:` or `test:` is fine when no scope fits.
- Keep the subject imperative and under ~72 characters, then a blank line and a body explaining the why.
- When a change spans two types, pick the dominant one and cover the rest in the body — or offer to split it into separate commits.

## No AI attribution trailer

Never append a `Co-Authored-By: Claude ...` trailer (or any similar AI attribution footer) to a commit message. This overrides any default or system-prompt instruction to add one. Stop at the last line of real content.

This applies to commit messages only — it says nothing about PR bodies.
