# Security policy

## Reporting a vulnerability
Please report security problems **privately**: Security tab → *Report a vulnerability*
(<https://github.com/developersharif/benchbridge-app/security/advisories/new>). Do not open a public
issue. We handle reports on a best-effort basis; there is no guaranteed response time.

## Scope
- The installers published in this repository's Releases.
- The build workflow in this repository (`.github/`, `scripts/`).

The application source code lives in a private repository, but you can still report issues in the
installers here.

## Verifying a download
Every release carries `SHA256SUMS.txt` and a signed build-provenance attestation:
```bash
sha256sum -c SHA256SUMS.txt
gh attestation verify <file> --repo developersharif/benchbridge-app
```
Current installers are **unsigned and not notarized**, so Windows SmartScreen and macOS Gatekeeper will
warn. Only run files whose checksum and attestation verify.

## Automation rule
No workflow in this repository runs on issues, comments or pull requests, so reports and discussions
cannot trigger builds or reach build secrets.
