<!-- CONTRIBUTING.md -->
# Contributing to Nootes

Thank you for your interest in contributing to Nootes! This document explains the preferred workflow, coding conventions and how to open a high-quality pull request.

1. Fork the repo and create a topic branch

```bash
git checkout -b feat/short-description
```

2. Code style & basics
- Follow existing code style. Keep diffs small and focused.
- Run analyzer and tests locally before pushing:

```bash
flutter analyze
flutter test
```

3. Tests
- Add unit tests for new behavior and bug fixes.
- For sync logic, prefer deterministic tests that use `InMemoryQueueStorage` and `DevFirestoreService`.

4. Commit messages
- Use imperative, present-tense commit messages, e.g. `fix(sync): handle null nextAttempt`.

5. Pull request
- Target the `feature/expanded-mvp` branch for MVP work, or `main` for smaller fixes.
- Include in PR description: summary, motivation, screenshots (if UI), and testing steps.

6. Review
- We aim to review small PRs within 48 hours. Expect comments about tests, analyzer warnings, and small style issues.

Thanks — contributors make this project possible.
