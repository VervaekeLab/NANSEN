%%  Install addons

addonManager = nansen.config.addons.AddonManager;

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


%% Todo: Set up default data location
