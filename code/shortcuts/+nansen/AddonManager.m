function addonManager = AddonManager(varargin)
%AddonManager Interface for managing addons
%
%   % This function is a "shortcut"
%
%   See also nansen.config.addons.AddonManager

    userSession = nansen.internal.user.NansenUserSession.instance();
    addonManager = userSession.getAddonManager();

    if ~nargout
        nansen.config.addons.AddonManagerApp(addonManager)
        clear addonManager
    end
end
