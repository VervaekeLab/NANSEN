# `nansen.config.addons`

This namespace contains the stateful addon-management layer for NANSEN.

Its responsibilities are:

- persist enriched addon records in `AddonList`
- install, update, and locate managed addons
- activate addons for the current MATLAB session
- provide addon-management UI

It consumes resolved dependency information from
`nansen.internal.dependencies`, but it owns installation side effects and
persisted addon state.

Main entry points:

- `AddonManager`
- `AddonManagerUI`
- `AddonManagerApp`
