# GitLab ↔ GitHub synchronization and GitHub Actions CI/CD

## Repositories

- **GitLab:** https://gitlab.com/chantinlongxthrx/I-steam
- **GitHub:** https://github.com/I-Steam/I-steam
- **Branch:** `main`

The project retains both configured synchronization directions:

1. **GitLab → GitHub:** the owner-configured GitLab push mirror publishes GitLab commits to GitHub. This is configured in GitLab project settings, not by a repository workflow.
2. **GitHub → GitLab:** `.github/workflows/blank.yml` pushes GitHub main commits to GitLab main using the existing `GITLAB_TOKEN` secret. This workflow has been restored byte-for-byte from the commit immediately before its accidental deletion and is intentionally left unchanged.

Do not edit, rename, disable, or delete `.github/workflows/blank.yml` without explicit owner approval. The scheduled `.github/workflows/mirror-from-gitlab.yml` polling workflow has been removed because the owner-configured GitLab push mirror already handles GitLab → GitHub synchronization. The GitLab CI configuration has also been removed; CI/CD runs on GitHub Actions.

## Important bidirectional-mirror caution

Two active push directions can race or create divergent histories if both sides receive independent commits. The GitHub → GitLab workflow contains ancestry checks and refuses some unsafe updates, but that is not a complete distributed synchronization protocol. Prefer making ordinary source commits in GitLab and letting its push mirror update GitHub. If GitHub-only commits are intentionally made, verify both refs and the sync workflow result before continuing. Never force-push either side to resolve a divergence without explicit review.

## GitHub Actions CI/CD

All CI/CD definitions live in `.github/workflows/` and execute on GitHub:

- `validate-repository.yml` — YAML/configuration validation, duplicate-key detection, QEMU source validation, and shell syntax checks.
- `validate-ios-build.yml` — iOS, tvOS, and visionOS simulator compile checks.
- `build-qemu-runtime.yml` — builds and packages the iOS arm64 QEMU/UTM runtime; supports manual and reusable-workflow calls.
- `release.yml` — builds the runtime first, then platform packages, publishes combined GitHub releases, and optionally updates the AltStore website using `PAGES_TOKEN`.
- `blank.yml` — synchronization only; not a build or validation job. Keep unchanged.

Required GitHub secrets are those used by workflows, including `GITLAB_TOKEN` for the retained GitHub → GitLab sync and `PAGES_TOKEN` for website publishing. The GitLab push-mirror credentials remain configured in GitLab settings and must not be committed to source.

## Mirror verification

The GitLab push mirror is external project configuration. Verify it in GitLab Settings → Repository → Mirroring repositories. Confirm the GitHub target, enabled status, and successful last update. This repository change does not alter those settings.

## Validation and limitations

- A successful GitHub workflow run proves only the checks it actually executes.
- Simulator compilation and IPA packaging do not prove physical-device installation, guest OS boot, persistence, or game compatibility.
- The QEMU runtime build must produce and package its artifact in the same release workflow run before the iOS app packaging job can proceed.
- GitHub Actions sync success and GitLab push-mirror success must be checked independently.
