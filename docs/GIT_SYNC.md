# GitLab-to-GitHub synchronization

GitLab is the canonical repository for i-Steam. GitHub at https://github.com/I-Steam/I-steam is a mirror used for GitHub Actions and releases.

## Branch policy

- Only GitLab `main` is automatically pushed to GitHub `main`.
- Feature branches stay in GitLab and are not automatically pushed to same-named GitHub branches. This avoids non-fast-forward failures when GitHub has independent branch history and avoids creating unnecessary pull requests.
- The sync job is serialized with the `github-sync-main` resource group.
- GitHub-to-GitLab recovery is a separate manual-only operation; ordinary GitHub pushes must not start a reverse-sync loop.

## Required secret

Set `GITHUB_SYNC_TOKEN` as a masked GitLab CI/CD variable with permission to write repository contents in `I-Steam/I-steam`. Do not print or commit the token. The main-only sync job checks authentication without printing credentials.

## Validation and troubleshooting

The GitLab validation job checks that the sync resource group, main-only rule, and explicit push destination remain in place. A feature-branch pipeline should skip `sync_to_github`; a main pipeline should push only to GitHub `main`.

If GitHub `main` itself rejects a push, inspect whether GitHub contains independent commits before changing history. Do not force-push or auto-merge feature branches to work around divergence. Reconcile the history through the canonical GitLab workflow, then retry.

Manual release dispatch uses the GitLab pipeline's `channel` input (`Nightly` or `Main`) and dispatches the GitHub release workflow on `main`.
