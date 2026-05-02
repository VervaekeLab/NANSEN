# `nansen.internal.dependencies`

Reads `dependencies.nansen.json` manifests and works out which
dependencies apply for a given combination of modules and workflows,
which are already installed, and which are missing.

Pure inspection — nothing here downloads, installs, or writes user state.
The install side lives in `nansen.config.addons`.

Functions:

- `readManifest` — parse one manifest file
- `resolveRequirements` — combine core + module manifests, dedupe and filter
- `checkInstallationStatus` — check installed / on-path state
- `getRequiredMathworksProducts` — list required MathWorks products
- `checkRequiredMathworksProducts` — warn or error on missing required products
