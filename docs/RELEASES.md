# Build and release workflow

The project uses one combined workflow: [`.github/workflows/release.yml`](../.github/workflows/release.yml). It builds iOS and tvOS as separate jobs, then publishes both platform artifacts together in a single GitHub release.

## Trigger behavior

| Trigger | Channel behavior |
| --- | --- |
| Push to `main` | Nightly only |
| Scheduled run | Nightly only, daily at 02:00 UTC |
| Manual GitHub Actions run | Requires a choice: `Nightly` or `Main` |
| Manual GitLab pipeline | Offers the same channel choice and dispatches the GitHub workflow |

Automatic events must not publish Main. Use the manual workflow input to publish Main intentionally.

## Release assets

A successful release is expected to contain:

- `iSteam-ios.ipa`
- `iSteam-ios.ipa.sha256`
- `iSteam-tvOS.ipa`
- `iSteam-tvOS.ipa.sha256`

The iOS app bundle identifiers are `com.xthrx.isteam` for Main and `com.xthrx.isteam.nightly` for Nightly. The tvOS identifiers are `com.xthrx.isteam.tvos` for Main and `com.xthrx.isteam.tvos.nightly` for Nightly. Versions follow `0.1.xxx`, with the build number derived from the workflow run.

The workflow verifies that the expected app bundle exists, checks bundle identifiers, validates IPA ZIP containers, and verifies SHA-256 files before publication. This verifies packaging integrity, not that the unsigned app can be installed or that its runtime works.

## Signing and installation

The produced IPAs are unsigned. The iOS IPA needs a compatible signing path before installation. The tvOS IPA is a separate prototype artifact and requires a compatible tvOS signing/provisioning and deployment path. Do not assume that an iOS sideloading tool can install the tvOS artifact.

## AltStore website publishing

The release workflow can update the [i-Steam website/source repository](https://github.com/I-Steam/I-steam.github.io) when the `PAGES_TOKEN` GitHub secret is present and has write access to that repository. If the secret is absent, release assets may still be published while website manifest updates are skipped. Inspect the workflow log to confirm website publishing.

The workflow's website step updates versioned download assets, stable download names and source-manifest entries. Keep the manifest bundle IDs and URLs consistent with the app's actual identifiers. Do not manually advertise the tvOS artifact as installable through an iOS AltStore client.

## Retention and old releases

The workflow does not include an automatic cleanup step for older GitHub releases. Do not add release deletion or asset-pruning behavior without an explicit project decision.

## Diagnosing a failure

1. Open [GitHub Actions](https://github.com/I-Steam/I-steam/actions/workflows/release.yml).
2. Open the failed run and inspect the first failing build step.
3. If both platform builds succeed but release publication fails, inspect artifact names, checksum verification, release permissions and any optional website publishing step.
4. Fix the root cause, rerun, and confirm the release contains both IPAs and both checksums.

## GitLab mirror and dispatch

The GitLab CI file pushes the current main branch to the GitHub repository using `GITHUB_SYNC_TOKEN`. A manual GitLab web pipeline also calls the GitHub Actions workflow-dispatch API. The token needs the repository contents/workflow permissions required for those actions. Never commit tokens into source files or logs.
