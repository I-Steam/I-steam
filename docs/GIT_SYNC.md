# GitLab → GitHub push mirror and GitHub Actions CI/CD

## Repositories

- **Source repository:** https://gitlab.com/chantinlongxthrx/I-steam
- **GitHub mirror:** https://github.com/I-Steam/I-steam
- **Mirrored branch:** `main`

GitLab is the source of truth. The repository owner has configured GitLab's built-in push mirror to push GitLab commits to GitHub. This is a server-side GitLab repository setting; it is not implemented by a scheduled GitHub Actions workflow.

## One-way synchronization

1. Make source changes and commits in GitLab.
2. GitLab's configured push mirror sends the GitLab branch to GitHub.
3. GitHub Actions runs CI/CD from the mirrored GitHub branch.
4. Do not push GitHub Actions-generated commits back to GitLab.
5. Do not add a reverse GitHub-to-GitLab workflow or a scheduled GitHub workflow that polls GitLab.

The old `.github/workflows/blank.yml` (GitHub → GitLab) and `.github/workflows/mirror-from-gitlab.yml` (scheduled GitLab polling from GitHub) are removed. The latter is redundant with the configured GitLab push mirror; the former would create a second, conflicting synchronization direction. The GitLab CI configuration is also removed so GitLab does not spend runner minutes dispatching GitHub workflows or duplicating validation.

**Mirror configuration note:** the mirror itself is managed in GitLab project settings. This code change does not edit or verify that remote setting. Confirm in GitLab Settings → Repository → Mirroring repositories that the push mirror targets `https://github.com/I-Steam/I-steam`, is enabled, and reports a successful last update. Keep credentials in GitLab's protected mirror configuration, never in repository files.

## GitHub Actions responsibilities

All CI/CD definitions live in `.github/workflows/` and execute on GitHub:

- `validate-repository.yml` — strict YAML/configuration validation, duplicate-key detection, QEMU source validation, and shell syntax checks.
- `validate-ios-build.yml` — iOS, tvOS, and visionOS simulator compile checks.
- `build-qemu-runtime.yml` — builds and packages the iOS arm64 QEMU/UTM runtime; supports manual and reusable-workflow calls.
- `release.yml` — builds the runtime first, then platform packages, publishes combined GitHub releases, and optionally updates the AltStore website using `PAGES_TOKEN`.

Required GitHub secrets are only those used by the GitHub workflows, such as `PAGES_TOKEN` for website publishing. There is no longer a `GITLAB_TOKEN` secret requirement for repository synchronization and no `MIRROR_TOKEN` requirement for scheduled mirror polling.

## Validation and limitations

- A successful GitHub workflow run proves only the checks it actually executes.
- Simulator compilation and IPA packaging do not prove physical-device installation, guest OS boot, persistence, or game compatibility.
- The QEMU runtime build must produce and package its artifact in the same release workflow run before the iOS app packaging job can proceed.
- The GitLab push mirror is external repository configuration. Its enabled state and last successful update must be checked in GitLab settings; deleting redundant workflows does not change that setting.
