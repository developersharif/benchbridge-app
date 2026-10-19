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
The macOS app is signed with a Developer ID and notarized; the `.dmg` file itself is not notarized. The
Windows and Linux installers are **unsigned**, so Windows SmartScreen will warn. Only run files whose checksum
and attestation verify.

## Automation rule
No workflow in this repository runs on issues, comments or pull requests, so reports and discussions
cannot trigger builds or reach build secrets.
