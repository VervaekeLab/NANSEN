function uninstall(options)
%uninstall Remove dependencies installed by NANSEN
%
%   nansen.uninstall() removes tracked add-ons from the default add-on
%   folder. NANSEN preferences are kept.
%
%   nansen.uninstall(Name=Value) options:
%       AddonFolder        - Folder to uninstall from. Default: NANSEN's
%                            default add-on folder.
%       DeleteAddons       - Remove tracked add-on folders (default: true).
%       DeletePreferences  - Also delete NANSEN preferences in prefdir
%                            (default: false).
%
%   For the default folder the entire folder is removed. For a custom
%   folder only paths tracked in the manifest are removed; the custom
%   root folder is preserved.

    arguments
        options.AddonFolder (1,1) string = missing
        options.DeleteAddons (1,1) logical = true
        options.DeletePreferences (1,1) logical = false
    end

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
    addonPaths = addonPaths(addonPaths ~= nansen.internal.utility.stripTrailingFilesep(addonFolder));
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
        nansen.internal.utility.stripTrailingFilesep(fileparts(manifestFilePath)), ...
        nansen.internal.utility.stripTrailingFilesep(addonFolder));
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
    addonPaths = unique(nansen.internal.utility.stripTrailingFilesep(addonPaths));
end

function tf = isPathInsideFolder(pathList, parentFolder)
    pathList = nansen.internal.utility.stripTrailingFilesep(pathList);
    parentFolder = nansen.internal.utility.stripTrailingFilesep(parentFolder);

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
