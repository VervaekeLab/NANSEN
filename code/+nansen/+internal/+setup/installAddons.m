function installAddons()
% installAddons - Install addons using nansen's addon manager

    addonManager = nansen.AddonManager();
    
    for i = 1:numel(addonManager.AddonList)
        S = addonManager.AddonList(i);
        if ~S.IsInstalled
            fprintf('Downloading %s...', S.Name)
            addonManager.downloadAddon(S.Name)
            addonManager.addAddonToMatlabPath(S.Name)
            fprintf('Finished.\n')
        end
    end
    
    addonManager.saveAddonList()
end
