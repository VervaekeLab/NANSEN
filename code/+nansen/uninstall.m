function uninstall(options)

    arguments
        options.AddonFolder (1,1) string = missing
        options.DeleteAddons (1,1) logical = true
        options.DeletePreferences (1,1) logical = false
    end

    % Remove dependencies installed by NANSEN.
    if options.DeleteAddons
        if ismissing(options.AddonFolder)
            options.AddonFolder = nansen.config.addons.getDefaultAddonFolder();
        end
        uninstallAddons(options.AddonFolder)
        nansen.config.addons.AddonManager.instance("clear");
    end

    % Remove NANSEN preferences
    if options.DeletePreferences
        nansenPreferenceDir = fullfile(prefdir, "Nansen");
        if isfolder(nansenPreferenceDir)
            rmdir(nansenPreferenceDir, "s")
        end
    end
end

function uninstallAddons(addonFolder)
    manifestFilePath = nansen.config.addons.getAddonManifestFilePath( ...
        addonFolder);

    if isDefaultAddonFolder(addonFolder, manifestFilePath)
        removeFolderFromPath(addonFolder)
        if isfolder(addonFolder)
            rmdir(addonFolder, "s")
        end
        return
    end

    addonPaths = getTrackedAddonPaths(manifestFilePath);
    addonPaths = addonPaths(isPathInsideFolder(addonPaths, addonFolder));
    addonPaths = addonPaths(addonPaths ~= stripTrailingFilesep(addonFolder));
    addonPaths = sort(addonPaths, "descend");

    for i = 1:numel(addonPaths)
        removeFolderFromPath(addonPaths(i))
        if isfolder(addonPaths(i))
            rmdir(addonPaths(i), "s")
        end
    end

    nansenMetadataFolder = fullfile(addonFolder, ".nansen");
    if isfolder(nansenMetadataFolder)
        rmdir(nansenMetadataFolder, "s")
    end
end

function tf = isDefaultAddonFolder(addonFolder, manifestFilePath)
    tf = strcmp( ...
        stripTrailingFilesep(fileparts(manifestFilePath)), ...
        stripTrailingFilesep(addonFolder));
end

function addonPaths = getTrackedAddonPaths(manifestFilePath)
    addonPaths = strings(1, 0);
    if ~isfile(manifestFilePath)
        return
    end

    savedData = jsondecode(fileread(manifestFilePath));
    if ~isfield(savedData, 'AddonList') || isempty(savedData.AddonList)
        return
    end

    addonList = savedData.AddonList;
    if iscell(addonList)
        addonList = [addonList{:}];
    end
    if ~isfield(addonList, 'FilePath')
        return
    end

    addonPaths = string({addonList.FilePath});
    addonPaths(addonPaths == "" | ismissing(addonPaths)) = [];
    addonPaths = unique(stripTrailingFilesep(addonPaths));
end

function tf = isPathInsideFolder(pathList, parentFolder)
    pathList = stripTrailingFilesep(pathList);
    parentFolder = stripTrailingFilesep(parentFolder);

    if ispc
        pathList = lower(pathList);
        parentFolder = lower(parentFolder);
    end

    tf = startsWith(pathList, parentFolder + filesep) | pathList == parentFolder;
end

function removeFolderFromPath(folderPath)
    if ~isfolder(folderPath)
        return
    end

    warningState = warning("off", "MATLAB:rmpath:DirNotFound");
    cleanup = onCleanup(@() warning(warningState)); %#ok<NASGU>
    rmpath(genpath(folderPath))
end

function folderPath = stripTrailingFilesep(folderPath)
    folderPath = string(folderPath);
    for i = 1:numel(folderPath)
        while strlength(folderPath(i)) > 1 && endsWith(folderPath(i), filesep)
            folderPath(i) = extractBefore(folderPath(i), strlength(folderPath(i)));
        end
    end
end
