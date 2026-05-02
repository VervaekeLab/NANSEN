% NANSEN.INTERNAL.DEPENDENCIES - Read manifests and work out what is needed
%
% Reads dependencies.nansen.json files and works out which dependencies
% apply for a given set of modules and workflows, what is already
% installed, and what is missing. Pure inspection — nothing here downloads
% or writes user state. The install side lives in nansen.config.addons.
%
% Functions
%   readManifest                    - Parse a dependencies.nansen.json file
%   resolveRequirements             - Combine core + module manifests, dedupe and filter
%   checkInstallationStatus         - Check IsInstalled and IsOnPath for a list of dependencies
%   getRequiredMathworksProducts    - List required MathWorks products
%   checkRequiredMathworksProducts  - Warn or error if required MathWorks products are missing
