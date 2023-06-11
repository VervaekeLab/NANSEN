function addonManager = AddonManager(varargin)
%AddonManager Interface for managing addons
%
%   % This function is a "shortcut"
%
%   See also nansen.addons.AddonManager

    if ~nargout
        nansen.addons.AddonManagerApp()
    else
        addonManager = nansen.addons.AddonManager();
    end
end
