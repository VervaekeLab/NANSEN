function addonManager = AddonManager(varargin)
%AddonManager Interface for managing addons
%
%   % This function is a "shortcut"
%
%   See also nansen.setup.model.Addons

    if ~nargout
        nansen.addons.AddonManagerApp()
    else
        addonManager = nansen.setup.model.Addons();
    end
end
