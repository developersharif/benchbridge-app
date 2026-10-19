# Maintainer guide: secure build & release

This **public** repository hosts downloads, bug reports and discussions, and also builds the installers
for benchbridge (Windows, macOS, Linux) from a **private** source repository (called "the source repo"
below). It contains no application source, only the build workflow.

Because this repository is public, its Actions logs and artifacts are world-readable. The workflow is
therefore designed so that **private source never reaches a public log or artifact**, and the finished
build is **stored as a release** while the run's logs are deleted.

## How a build works

```
you: Run workflow with source_sha (full commit SHA from benchbridge `main`)
  └─ verify-source   check out that exact commit (read-only deploy key), prove it is on `main`
  └─ build ×3        linux (.deb .rpm) · windows (NSIS .exe) · macOS universal (.dmg)
  │                  tool output goes to a log file, NOT to the public log
  └─ release         stores the build: SHA256SUMS + signed provenance attestation + DRAFT pre-release
                     (draft = not public until you publish it after a smoke test)
  └─ clean-build-logs (separate workflow) deletes the run's logs after it finishes
```

Only manual runs (`workflow_dispatch`) exist. **No workflow runs on issues, comments or pull requests**, so
public reports and discussions cannot start a build or reach the secrets.

## One-time setup (needs repository admin; takes ~5 minutes)

1. **Deploy key (read-only access to the private source).**
   ```bash
   ssh-keygen -t ed25519 -N '' -C benchbridge-build -f ./bb_deploy_key
   ```
   - In the **source repo** → Settings → Deploy keys → *Add*: paste `bb_deploy_key.pub`,
     leave **"Allow write access" unchecked**.
   - In this repo → Settings → Environments → **`release`** → add secret **`SOURCE_DEPLOY_KEY`** =
     contents of `bb_deploy_key` (the private key). Then delete the local key files.
2. **Optional: encrypted debug logs.** Add environment secret **`LOG_ENCRYPTION_KEY`** (e.g.
   `openssl rand -base64 32`). Without it, no build log is kept at all.
3. **Protect the `release` environment:** add yourself as *Required reviewer* and limit *Deployment
   branches* to `main`. Every job that uses the key then waits for your approval.
4. **Public-facing features:** enable *Issues* and *Discussions*, and *Private vulnerability reporting*
   (Settings → Code security) so the links in `.github/ISSUE_TEMPLATE/config.yml` and `SECURITY.md` work.
5. **Repository settings:** Actions → General → *Fork pull request workflows*: require approval;
   *Workflow permissions*: read-only; *Allow GitHub Actions to create and approve pull requests*: off;
   *Actions permissions*: allow only GitHub-created actions. Protect `main` (require pull-request review, including *Code Owners*; see `.github/CODEOWNERS`).

## Run a build

Actions → **build-release** → *Run workflow* → paste the full 40-character SHA
(`git rev-parse HEAD` in the source repo, on `main`). *draft_release* is on by default: the installers
are stored as a **draft pre-release** (the stored build). Smoke-test them, then publish the release
yourself. With it off, installers are only kept as workflow artifacts for 3 days.

Verify a downloaded file:
```bash
sha256sum -c SHA256SUMS.txt
gh attestation verify <file> --repo developersharif/benchbridge-app
```

## Security model

| Risk | Control |
|---|---|
| Private source in public logs | Tool output (cargo/npm/tauri) is redirected to a file; failures print one generic line. `clean-build-logs` deletes the run's logs when it finishes. |
| Private source in public artifacts | Only the installers (and, optionally, an AES-256 **encrypted** log) are uploaded, never source, `target/` or `node_modules/`. Artifacts expire after 3 days. |
| Building the wrong or a tampered commit | `source_sha` must be a full SHA, equal to the checked-out `HEAD`, and an ancestor of `origin/main`. Branch names and tags are not accepted. |
| Stolen source-access credential | Read-only **deploy key** for one repository, released only to the `release` environment (optionally gated by a reviewer). It is never persisted in git config. |
| Compromised or moved third-party action | Only `actions/*`, each pinned to a full commit SHA (version in a comment); Dependabot proposes updates. |
| Script injection via inputs | Inputs are never interpolated into shell; they pass through `env` and are regex-validated. |
| Over-privileged token | `permissions: {}` at the top; each job lists only what it needs; only `release` can write, only the log cleaner has `actions: write`. |
| Poisoned build cache | No dependency or build caches. `npm ci --ignore-scripts`; Rust pinned to an exact version. |
| Concurrent / runaway builds | One run at a time; job timeouts. |
| Unverifiable downloads | SHA256SUMS plus a signed build-provenance attestation for the release files. |

**Trade-offs, stated plainly**
- Deleting logs removes the audit trail of *how* a build ran. The durable evidence is the release's
  checksums and attestation. Set the repository variable `KEEP_LOGS=true` to keep logs while debugging the
  workflow itself (default is to delete).
- Without `LOG_ENCRYPTION_KEY`, a failed build cannot be diagnosed from GitHub; reproduce it locally.
- The installers are public (that is the point) and, like any binary, contain compiled code and relative
  source file names in panic messages (checked on the Linux build only: no absolute build paths). They do not contain source.
- Builds are **not reproducible bit-for-bit**; the attestation proves *which workflow run* built a file,
  not that rebuilding gives identical bytes.

## Public reports and discussions

Issue forms (`.github/ISSUE_TEMPLATE/`) warn reporters not to post readings or confidential data and ask
for the app's *Copy support info* text, which contains only versions, states and counters. Nothing
automated reads issue text. Treat issue content as untrusted input if you ever add automation.

## Signing

**macOS: implemented.** The build step passes `APPLE_CERTIFICATE`, `APPLE_CERTIFICATE_PASSWORD`,
`APPLE_SIGNING_IDENTITY`, `APPLE_ID`, `APPLE_PASSWORD` (an app-specific password) and `APPLE_TEAM_ID` to the
macOS leg only. They are secrets of the `release` environment, never plain repository secrets. Tauri signs
the app (hardened runtime) and notarizes and staples it. Checked on a real Mac for run 39233912289
(2026-10-19): the `.app` is `Notarized Developer ID` (`spctl`), `stapler validate` passes, and a
Safari-downloaded `.dmg` showed only macOS's standard "downloaded from the Internet" confirmation.
- The `.dmg` file itself is signed but **not notarized** (`spctl` reports "Unnotarized Developer ID" for the
  dmg, and no ticket is stapled to it). Only the app inside is notarized.
- If a secret is missing, the build is **not expected to fail**; it would produce an unsigned dmg. Verify
  every release with `codesign -dv`, `spctl --assess -vv` and `xcrun stapler validate`.

**Windows and Linux: not signed.** Windows needs an Authenticode certificate; not implemented.

## Status (read before relying on this)

Checked locally on Linux (2026-10-18; the issue forms were only checked as valid YAML with the
expected structure, not rendered by GitHub):
- `shellcheck` clean; `actionlint 1.7.12` clean; policy check (only `workflow_dispatch`/`workflow_run`,
  every action SHA-pinned, no expressions inside `run:` blocks) passes.
- `scripts/verify-source.sh` tested against a real full clone: accepts commits on `main`; rejects a
  malformed SHA, an injection payload (not executed), a mismatched checkout, a commit not on `main`, and a
  checkout without `origin/main`.
- `scripts/build-installers.sh` run for real on Linux: produced a `.deb` and `.rpm`, printed no tool output,
  removed the plain log, and the encrypted log decrypted only with the right key. Failure path tested.
- Action pins were resolved from the actions' own repositories and their inputs checked against each
  `action.yml` at the pinned commit.

**Never run on GitHub yet:** the workflows themselves; the Windows and macOS builds (NSIS and universal
`.dmg`, bundle paths assumed from tooling behaviour); deploy-key checkout; environment gating; the provenance
attestation; draft release creation; the log-deletion API call. Treat the first real run as a test, with
`KEEP_LOGS=true`.
