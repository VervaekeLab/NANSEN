function install(options)
% install - Install missing nansen dependencies.

    arguments
        options.AddonFolder (1,1) string = nansen.config.addons.getDefaultAddonFolder()
    end

    addonManager = nansen.config.addons.AddonManager.instance("AddonFolder", options.AddonFolder);
    addonManager.downloadAndInstallMatBox();
    addonManager.installMissingAddons();

    nansen.internal.setup.verifyInstallation()
end
