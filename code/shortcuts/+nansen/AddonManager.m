function addonManager = AddonManager(mode, options)
%AddonManager Interface for managing addons
%
%   % This function is a "shortcut"
%   addonManager = nansen.AddonManager("AddonFolder", addonFolder) returns
%   a manager for a specific NANSEN add-on folder.
%   addonManager = nansen.AddonManager("reset", "AddonFolder", addonFolder)
%   forces a reset with a specific NANSEN add-on folder.
%
%   See also nansen.config.addons.AddonManager

    arguments
        mode (1,1) string {mustBeMember(mode, ["normal", "reset", "clear"])} = "normal"
        options.AddonFolder (1,1) string = missing
    end

    addonManager = nansen.config.addons.AddonManager.instance( ...
        mode, "AddonFolder", options.AddonFolder);

    if mode == "clear"
        clear addonManager
    elseif ~nargout
        nansen.config.addons.AddonManagerApp(addonManager)
        clear addonManager
    end
end
