# GitLab ↔ GitHub synchronization

## Repositories and branches

- **GitLab:** https://gitlab.com/chantinlongxthrx/I-steam
- **GitHub:** https://github.com/I-Steam/I-steam
- **Branch:** `main` on both repositories

GitHub commits to `main` are automatically pushed to GitLab by `.github/workflows/blank.yml`. The existing GitHub Actions mirror workflow also polls GitLab every 15 minutes so direct GitLab-side commits can reach GitHub. Both directions compare commit ancestry and avoid force-pushing.

## Required GitHub secret

Add a GitLab project access token to **I-Steam/I-steam → Settings → Secrets and variables → Actions**:

- **Secret name:** `GITLAB_TOKEN`
- **GitLab project:** `chantinlongxthrx/I-steam`
- **Required scope/role:** `write_repository` (or a token with equivalent repository push permission)
- **Token value:** store only as the GitHub Actions secret; never commit or paste it into source files.

The workflow fails early with a clear error if the secret is missing or cannot push.

The GitLab-to-GitHub mirror still requires `MIRROR_TOKEN` with Contents read/write and Workflows read/write on the GitHub repository. This is separate from `GITLAB_TOKEN`.

## Push behavior

1. A push to GitHub `main` starts the GitHub-to-GitLab workflow.
2. The workflow checks out full Git history and fetches GitLab `main`.
3. If both refs match, it exits successfully without writing.
4. If GitHub is ahead and GitLab is an ancestor, it pushes a fast-forward update.
5. If GitLab is ahead, it refuses to overwrite the newer GitLab commit.
6. If histories diverged, it merges GitLab into the checked-out GitHub commit, preferring GitHub file contents for conflicts, then pushes the merge.
7. It never force-pushes.

The GitLab-to-GitHub mirror can cause the reverse workflow to start after a mirror update. That run sees identical commit IDs and exits without pushing, preventing a loop. Do not add an unconditional push or force-push step to either workflow.

## Validation and limitations

- Confirm `GITLAB_TOKEN` is configured before relying on automatic pushes.
- The workflow synchronizes Git history only; it does not prove the iOS/tvOS/visionOS app builds or that QEMU boots on a device.
- A successful run proves that the GitHub commit reached GitLab, not that GitLab CI runners were available.
- GitLab-side commits may take up to 15 minutes to appear on GitHub through the scheduled mirror.
