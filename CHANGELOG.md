# Changelog

Versions follow [Semantic Versioning](https://semver.org). The agent API is
versioned separately (`api_version`, currently `v1`); a release never changes
`v1` incompatibly.

## 1.1.0 - 2026-11-06

### Added

- `GET /api/v1/health` reports `version` (the software release) and
  `api_version`, so a client can check compatibility before relying on a
  field.
- `GET /api/v1/whoami` checks a token. It does not touch X or the rate-limit
  budget, so an agent can validate its configuration for free.
- `GET /api/v1/openapi.json` now describes response bodies: a `data` schema
  per tool for `User`, `Tweet` and the other objects, plus `Health`,
  `Whoami` and `Error`. A test validates real output against them, so they
  cannot drift.
- Container images on the GitHub Container Registry, `ghcr.io/xiaoy233/nitter`,
  for `linux/amd64` and `linux/arm64`. An image is built when a `v*` tag is
  pushed; pushes to `master` only run the tests.
- Agent skill `nitter-x` replaces three skills that depended on each other
  (`nitter-research`, `nitter-thread-digest`, `nitter-account-brief`). The task
  guides load on demand. Includes Codex metadata and an icon.

### Changed

- Error pages in the X layout are a plain card with a coloured icon instead of
  a block of the error colour. The old layout made the message unreadable in
  the TikTok theme.
- CI runs on this repository: unit tests on Nim 2.0 and 2.2, an image build for
  both architectures, and a smoke test of the image against Redis.

### Upgrade notes

- If you installed the three old skills, remove them and install `nitter-x`
  (see `skills/README.md`). The tools and their arguments are unchanged.
- `nitter.nimble`, `serverVersion` in `src/tools/core.nim` and
  `clients/mcp-stdio/package.json` all say 1.1.0; a test keeps the first two
  equal.

## 1.0.0 - 2026-11-04

First release of this fork: the read-only agent API (REST, MCP, Skills), the
themed web interface (X, Vercel, Mono, Claude, Codex, TikTok), the Chinese
interface, and the documentation. See the
[release notes](https://github.com/xiaoY233/nitter/releases/tag/v1.0.0).
