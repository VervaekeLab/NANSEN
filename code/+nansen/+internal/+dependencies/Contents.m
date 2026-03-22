% Overview for nansen.internal.dependencies namespace.
% Dependency manifest utilities for NANSEN.
%
% This package is the stateless dependency layer. It reads dependency
% manifests, resolves dependencies across scopes, and computes dependency
% status for the current MATLAB session.
%
% Functions
%   readManifest                    - Parse a dependencies.nansen.json file.
%   resolveRequirements             - Resolve, deduplicate, and filter dependencies.
%   checkInstallationStatus         - Compute IsInstalled and IsOnPath status.
%   getRequiredMathworksProducts    - List required MathWorks products.
%   checkRequiredMathworksProducts  - Warn or error on missing MathWorks products.
