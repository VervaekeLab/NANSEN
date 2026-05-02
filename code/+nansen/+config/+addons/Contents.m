% NANSEN.CONFIG.ADDONS - Install and track community toolboxes used by NANSEN
%
% Reads the resolved dependency list from nansen.internal.dependencies and
% handles the side that touches disk: downloading addons, keeping a record
% of what is installed, and adding them to the MATLAB path.
%
% Files
%   AddonPreferences          - Preferences for addon management
%
% Functions
%   getDefaultAddonFolder     - Default folder for NANSEN add-ons (under userpath)
%   getAddonManifestFilePath  - Manifest path for a given add-on folder
%
% Classes
%   AddonManager              - Install, update and activate addons
%   AddonManagerUI            - Table UI for managing addons
%   AddonManagerApp           - App wrapper for AddonManagerUI
%
% See also nansen.internal.dependencies
