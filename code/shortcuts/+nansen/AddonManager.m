function addonManager = AddonManager(varargin)
%AddonManager Interface for managing addons
%
%   % This function is a "shortcut"
%
%   See also nansen.config.addons.AddonManager

    addonManager = nansen.config.addons.AddonManager.instance();

    if ~nargout
        nansen.config.addons.AddonManagerApp(addonManager)
        clear addonManager
    end
end
