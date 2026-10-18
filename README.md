# benchbridge-app: secure build & release workflow

This **public** repository builds the installers for **benchbridge** (Windows, macOS, Linux) from a
**private** source repository, [`developersharif/benchbridge`](https://github.com/developersharif/benchbridge).
It contains no application source, only the build workflow.

Because this repository is public, its Actions logs and artifacts are world-readable. The workflow is
therefore designed so that **private source never reaches a public log or artifact**.

## How a build works

```
you: Run workflow with source_sha (full commit SHA from benchbridge `main`)
  └─ verify-source   check out that exact commit (read-only deploy key), prove it is on `main`
  └─ build ×3        linux (.deb .rpm) · windows (NSIS .exe) · macOS universal (.dmg)
  │                  tool output goes to a log file, NOT to the public log
  └─ release         optional: SHA256SUMS + signed provenance attestation + DRAFT pre-release
  └─ clean-build-logs (separate workflow) deletes the run's logs after it finishes
```

Only manual runs (`workflow_dispatch`) exist: no pull-request or push triggers, so nobody else can start
a build or reach the secrets.

## One-time setup (needs repository admin; takes ~5 minutes)

1. **Deploy key (read-only access to the private source).**
   ```bash
   ssh-keygen -t ed25519 -N '' -C benchbridge-build -f ./bb_deploy_key
   ```
   - In `developersharif/benchbridge` → Settings → Deploy keys → *Add*: paste `bb_deploy_key.pub`,
     leave **"Allow write access" unchecked**.
   - In this repo → Settings → Environments → **`release`** → add secret **`SOURCE_DEPLOY_KEY`** =
     contents of `bb_deploy_key` (the private key). Then delete the local key files.
2. **Optional: encrypted debug logs.** Add environment secret **`LOG_ENCRYPTION_KEY`** (e.g.
   `openssl rand -base64 32`). Without it, no build log is kept at all.
3. **Protect the `release` environment:** add yourself as *Required reviewer* and limit *Deployment
   branches* to `main`. Every job that uses the key then waits for your approval.
4. **Repository settings:** Actions → General → *Fork pull request workflows*: require approval;
   *Workflow permissions*: read-only; *Allow GitHub Actions to create and approve pull requests*: off;
   *Actions permissions*: allow only GitHub-created actions. Protect `main` (require review).

## Run a build

Actions → **build-release** → *Run workflow* → paste the full 40-character SHA
(`git rev-parse HEAD` in the source repo, on `main`). Tick *draft_release* to also produce a draft
pre-release; otherwise installers are kept as artifacts for 3 days.

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

## Not signed (yet)

Installers are **unsigned and not notarized**, so Windows SmartScreen and macOS Gatekeeper will warn. Signing
needs certificates this repo does not have (Windows Authenticode certificate; Apple Developer ID +
notarization credentials). It should be added as environment secrets in the `release` environment, never
as plain repository secrets. Not implemented.

## Status (read before relying on this)

Checked locally on Linux (2026-10-18):
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
