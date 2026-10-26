# GitLab ↔ GitHub synchronization

**Canonical repository:** [GitLab i-Steam](https://gitlab.com/chantinlongxthrx/I-steam)  
**Mirror:** [GitHub i-Steam](https://github.com/I-Steam/I-steam)

## Expected behavior

- Normal development and merge requests happen in GitLab.
- The `.gitlab-ci.yml` job `sync_to_github` runs only for the `main` branch and directly pushes the commit to GitHub `refs/heads/main`.
- Feature branches remain in GitLab while under review. They are not mirrored as GitHub branches, preventing automatic GitHub PRs from being created for every feature-branch sync.
- `.github/workflows/blank.yml` is manual-only. It does not run on ordinary GitHub pushes, avoiding automatic bidirectional sync loops. GitLab remains canonical.
- The sync uses the masked `GITHUB_SYNC_TOKEN` GitLab CI/CD variable with permission to push to `I-Steam/I-steam`. Never store this token in source control.

## Validation

The GitLab CI validation checks that the sync job is main-only, pushes directly to GitHub main, does not push feature branch refs, and that the reverse-sync workflow has no automatic push trigger.

## Intentional recovery

If GitHub main contains a deliberate change that must be recovered into GitLab, use the GitHub Actions **Manual GitHub → GitLab Recovery Sync** workflow only after reviewing the diff. Do not enable automatic bidirectional syncing.
