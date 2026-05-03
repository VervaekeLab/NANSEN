# `nansen.config.addons`

Handles the side of NANSEN dependency management that touches disk and
MATLAB's path: downloading and updating community toolboxes, keeping a
record of what's installed, and exposing UI for users who want to manage
their addons themselves.

Pairs with `nansen.internal.dependencies`, which works out *what* should
be installed; this namespace acts on those decisions.

Main entry points:

- `AddonManager` — the singleton most callers should use
- `AddonManagerUI` — table UI showing the current addon list
- `AddonManagerApp` — app wrapper around the UI
