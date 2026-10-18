# benchbridge

Reads measurements from **serial weighing scales and laboratory balances** and saves them on your own
computer (SQLite, exportable to CSV). Local-first: no account, no cloud.

> **Early version.** No instrument model has been verified with benchbridge yet, and the built-in demo
> uses synthetic data. Installers are **unsigned**, so your operating system will warn before running them.

This repository is where you **download builds**, **report problems** and **ask questions**. It does not
contain the application source code.

## Download

Go to **[Releases](https://github.com/developersharif/benchbridge-app/releases)** and pick the file for your system:

| System | File |
|---|---|
| Windows | `.exe` installer |
| macOS (Apple silicon and Intel) | `.dmg` |
| Linux (Debian, Ubuntu) | `.deb` |
| Linux (Fedora, RHEL) | `.rpm` |

Check what you downloaded before running it:

```bash
sha256sum -c SHA256SUMS.txt                                   # use `shasum -a 256 -c` on macOS
gh attestation verify <file> --repo developersharif/benchbridge-app
```

The attestation proves the file was produced by this repository's build workflow.

## Report a problem or ask a question

- **Something broke?** Open an [issue](https://github.com/developersharif/benchbridge-app/issues/new/choose) using *Bug report*. In the app, open
  **Diagnostics → Copy support info** and paste it in. That text contains only versions, states and
  counters, never readings.
- **Using a specific scale or balance?** Use the *Instrument compatibility* form. Support is added only
  from the manual's protocol description, ideally with a tester who owns that exact model.
- **Questions and ideas:** use [Discussions](https://github.com/developersharif/benchbridge-app/discussions).
- **Security problems:** see [SECURITY.md](SECURITY.md). Please do not use public issues.

Please never post readings, serial numbers, or lab, patient or customer data.

## How the builds are made

Installers are built by a locked-down GitHub Actions workflow from a private source repository, on
GitHub's runners. The build output is deliberately **not** published: build logs are deleted after each
run so that nothing about the private source ends up in public logs. What stays is the finished
installers, a checksum file and a signed provenance attestation. Maintainers: see
[BUILDING.md](BUILDING.md).

## Contributing

There is no application code here to send patches to. Issues and discussions are very welcome. Changes to
the build workflow (`.github/`, `scripts/`) need the owner's review.
