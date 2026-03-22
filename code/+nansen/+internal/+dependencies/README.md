# `nansen.internal.dependencies`

This namespace contains the stateless dependency layer for NANSEN.

Its responsibilities are:

- read dependency manifests
- resolve dependencies across core and module scopes
- deduplicate and filter dependency requirements
- compute dependency status for the current MATLAB session

It should not own installation side effects, UI, or persisted addon state.

Functions:

- `nansen.internal.dependencies.readManifest`
- `nansen.internal.dependencies.resolveRequirements`
- `nansen.internal.dependencies.checkInstallationStatus`
- `nansen.internal.dependencies.getRequiredMathworksProducts`
- `nansen.internal.dependencies.checkRequiredMathworksProducts`
