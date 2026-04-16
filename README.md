# GilmanLab Infra

This repository contains infrastructure configuration, provisioning automation,
and supporting repository tooling for the GilmanLab homelab.

The first active project is `network/vyos`, which holds the VyOS gateway
configuration and validation flow. Additional infrastructure domains can be
added as separate Moon projects without reworking the repository baseline.

## Quick Start

Prerequisites:

- `moon` 2.x
- `python3`
- access to the sibling `secrets/` repo when working with secret-backed flows

Validate the current repository:

```sh
moon ci --summary minimal
```

Run the current VyOS validation target directly:

```sh
moon run network-vyos:check
```

## Current Projects

- `network/vyos`: VyOS gateway automation, config, and static validation

## Support

- Questions and design discussion: GitHub Discussions
- Non-security bugs: GitHub Issues
- Vulnerabilities: follow [SECURITY.md](SECURITY.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
