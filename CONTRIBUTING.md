# Contributing

Thank you for contributing to `GilmanLab/infra`.

Use GitHub Discussions for architecture and workflow questions. Use GitHub
Issues for non-security bugs. For vulnerabilities, stop and follow
[SECURITY.md](SECURITY.md) instead of using public channels.

## Pull Requests

1. Keep changes scoped to one infrastructure domain or automation concern.
2. Update validation or documentation when behavior changes.
3. Describe operator impact clearly in the pull request.
4. Make sure CI passes before requesting review.

## Local Setup

Validate the repository baseline:

```sh
moon ci --summary minimal
moon run network-vyos:check
```
