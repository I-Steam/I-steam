# GitLab ↔ GitHub synchronization

## Canonical direction

- **Canonical repository:** https://gitlab.com/chantinlongx/I-steam
- **Mirror repository:** https://github.com/I-Steam/I-steam
- **Canonical branch:** `main`
- **Mirror branch:** `main`

GitLab is the source of truth. GitHub Actions polls public GitLab `main` every 15 minutes and can also be started manually from the Actions tab. This replaces the previous GitLab-runner-based `sync_to_github` job, which could not start when the GitLab shared-runner quota was exhausted.

The GitHub-to-GitLab recovery workflow (`.github/workflows/blank.yml`) remains manual-only. Do not enable automatic push triggers on it; that would create a bidirectional sync loop.

## Required GitHub secret

Create a fine-grained personal access token and add it to **I-Steam/I-steam → Settings → Secrets and variables → Actions**:

- Secret name: `MIRROR_TOKEN`
- Repository access: only `I-Steam/I-steam`
- Repository permissions:
  - **Contents: Read and write**
  - **Workflows: Read and write**

The Workflows permission is required because a complete mirror may need to update files under `.github/workflows/`. Never commit or paste the token into the repository or chat. The workflow fails early with a clear message if the secret is missing.

## Sync behavior

1. Check out GitHub `main` with full history.
2. Fetch GitLab `main` over its public HTTPS URL; no GitLab credential is needed.
3. If both branches point to the same commit, do nothing.
4. If GitLab is ahead, fast-forward GitHub to the GitLab commit.
5. If histories diverged, merge GitLab into GitHub and prefer GitLab's file contents on conflicts.
6. If GitHub is ahead of GitLab, do not force-push or discard GitHub-only commits; report a warning and leave the branch unchanged for manual reconciliation.
7. Push to GitHub `main` without force.

Only the scheduled/manual GitHub workflow writes the mirror. The GitLab CI file no longer contains a second automatic push job, preventing competing writers.

## Activation

The workflow source is committed at `.github/workflows/mirror-from-gitlab.yml`. It must exist on GitHub once before GitHub Actions can schedule it. If the GitLab-to-GitHub push that installs this workflow is blocked by GitLab runner quota, add this file to GitHub `main` manually using the GitHub web editor, then add `MIRROR_TOKEN` and run **GitLab to GitHub Mirror** once from the Actions tab.

Workflow source:
https://gitlab.com/chantinlongx/I-steam/-/blob/main/.github/workflows/mirror-from-gitlab.yml

## Validation and limitations

- YAML syntax and shell steps must be checked before activation.
- The scheduled poll is not an instant push trigger; allow up to 15 minutes after a GitLab commit.
- A GitHub-ahead branch is intentionally not force-reset. Reconcile that state manually, then rerun the workflow.
- A successful mirror run proves repository synchronization only. It does not prove the iOS/tvOS/visionOS app builds or that the QEMU runtime boots on a device.
