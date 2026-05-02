function addonManager = AddonManager(options)
%AddonManager Interface for managing addons
%
%   % This function is a "shortcut"
%   addonManager = nansen.AddonManager("AddonFolder", addonFolder) returns
%   a manager for a specific NANSEN add-on folder.
%
%   See also nansen.config.addons.AddonManager

    arguments
        options.AddonFolder (1,1) string = missing
    end

    if ismissing(options.AddonFolder)
        addonManager = nansen.config.addons.AddonManager.instance();
    else
        addonManager = nansen.config.addons.AddonManager.instance( ...
            "reset", options.AddonFolder);
    end

    if ~nargout
        nansen.config.addons.AddonManagerApp(addonManager)
        clear addonManager
    end
end
