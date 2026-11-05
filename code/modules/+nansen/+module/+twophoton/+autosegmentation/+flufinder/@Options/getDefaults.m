function [P, V] = getDefaults()

% DESCRIPTION:
%   Change these parameters to change the behavior of the autosegmentation

% - - - - - - - - Specify parameters and default values - - - - - - - -

    [P, V] = nansen.module.twophoton.autosegmentation.flufinder.getDefaultOptions();

    %P = quickr.getOptions();
    %V = struct();

% - - - - - Adapt output to how many outputs are requested - - - - - -

if nargout == 0
    displayParameterTable(which('nansen.module.twophoton.autosegmentation.flufinder.getDefaultOptions'))
    clear P V
elseif nargout == 1
    clear V
end
end
