function manifestFilePath = getAddonManifestFilePath(addonFolder)
%getAddonManifestFilePath Return the manifest path for an add-on folder.

    arguments
        addonFolder (1,1) string = nansen.config.addons.getDefaultAddonFolder()
    end

    if isDefaultAddonFolder(addonFolder)
        manifestFilePath = fullfile(addonFolder, 'installed_addons.json');
    else
        manifestFilePath = fullfile(addonFolder, '.nansen', 'installed_addons.json');
    end
end

function tf = isDefaultAddonFolder(addonFolder)
    if isempty(userpath())
        tf = false;
        return
    end

    defaultAddonFolder = nansen.config.addons.getDefaultAddonFolder();

    addonFolder = stripTrailingFilesep(char(addonFolder));
    defaultAddonFolder = stripTrailingFilesep(char(defaultAddonFolder));

    if ispc
        tf = strcmpi(addonFolder, defaultAddonFolder);
    else
        tf = strcmp(addonFolder, defaultAddonFolder);
    end
end

function folderPath = stripTrailingFilesep(folderPath)
    while numel(folderPath) > 1 && endsWith(folderPath, filesep)
        folderPath = folderPath(1:end-1);
    end
end
