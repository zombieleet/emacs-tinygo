# Changelog

All notable changes to this project are documented here.

## [Unreleased]

### Fixed

- Pass the required context arguments to Eglot server-contact functions.
- Restart Eglot and lsp-mode with their required server/workspace objects.
- Validate interactive targets before changing project state.

### Changed

- Interactive target selections now apply to all open Go buffers in a project.
- Go buffers beneath `.tinygo-target` now start TinyGo LSP support by default.
- Automatic client selection now respects active or loaded lsp-mode setups.

### Added

- Initial public release with Eglot and lsp-mode integration.
- Target discovery through `.tinygo-target` and directory-local variables.
- ERT tests and GitHub Actions continuous integration.
