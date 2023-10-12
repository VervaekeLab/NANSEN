function addonManager = AddonManager(varargin)
%AddonManager Interface for managing addons
%
%   % This function is a "shortcut"
%
%   See also nansen.config.addons.AddonManager

    if ~nargout
        nansen.config.addons.AddonManagerApp()
    else
        addonManager = nansen.config.addons.AddonManager();
    end
end
