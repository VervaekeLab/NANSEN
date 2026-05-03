classdef AddonManager < handle
%AddonManager Manages community toolbox dependencies for NANSEN.
%   Tracks installed addons, delegates download/install to matbox,
%   and manages MATLAB path additions per session.

    properties
        % InstallationFolder - Folder to install Add-Ons (dependencies) for NANSEN
        InstallationFolder (1,1) string = missing
    end

    properties (SetAccess = private)
        % ManifestFilePath - Filepath for JSON manifest storing info and
        % installation status about Add-Ons managed by NANSEN
        ManifestFilePath (1,1) string
    end

    properties (Dependent)
        % ManagedAddons - Table listing information about managed Add-Ons
        ManagedAddons table
    end

    properties (SetAccess=private, Hidden)
        AddonList struct = struct() % ManagedAddons
    end

    properties (Hidden)
        IsDirty = false
    end

    properties (Constant, Hidden)
        DefaultAddonEntry = struct( ...
            'Name', '', ...
            'Description', "", ...
            'IsRequired', false, ...
            'IsInstalled', false, ...
            'IsOnPath', false, ...
            'DateInstalled', 'N/A', ...
            'FilePath', '', ...
            'Source', '', ...
            'DocsSource', '', ...
            'SetupFunctionName', '', ...
            'InstallCheck', '', ...
            'InstallationType', '', ...
            'ToolboxIdentifier', '', ...
            'HasMultipleInstancesOnPath', false)
    end

    methods (Access = private) % Constructor (private -> singleton)
        function obj = AddonManager(installationFolder)
            arguments
                installationFolder (1,1) string
            end
            obj.InstallationFolder = installationFolder;
            obj.ManifestFilePath = nansen.config.addons.getAddonManifestFilePath( ...
                installationFolder);
            obj.loadAddonManifest()
            obj.ensureAddonDependenciesOnPath()
            obj.checkAddonDuplication()
        end
    end

    methods (Static, Hidden) % Get singleton instance
        function obj = instance(mode, options)
        %instance Get the singleton AddonManager instance.
        %
        %   obj = AddonManager.instance() returns the singleton instance,
        %   creating it with default paths if needed.
        %
        %   obj = AddonManager.instance("reset") resets the singleton.
        %   obj = AddonManager.instance("clear") clears the singleton.
        %
        %   obj = AddonManager.instance("AddonFolder", folder) returns the
        %   singleton, creating or resetting it if the folder differs.
        %
        %   obj = AddonManager.instance("reset", "AddonFolder", folder)
        %   forces a reset with a specific add-on folder.

            arguments
                mode (1,1) string {mustBeMember(mode, ["normal", "reset", "clear"])} = "normal"
                options.AddonFolder (1,1) string = missing
            end

            persistent singletonInstance
            if mode == "clear"
                singletonInstance = [];
                obj = [];
                return
            end

            if ismissing(options.AddonFolder)
                options.AddonFolder = nansen.config.addons.getDefaultAddonFolder();
            end

            folderChanged = ~isempty(singletonInstance) && isvalid(singletonInstance) && ...
                ~singletonInstance.isSameFolder(options.AddonFolder);
            if isempty(singletonInstance) || ~isvalid(singletonInstance) || mode == "reset" || folderChanged
                singletonInstance = nansen.config.addons.AddonManager( ...
                    options.AddonFolder);
            end
            obj = singletonInstance;
        end
    end

    methods % Public

        % Open the Add-On Manifest in MATLABs editor
        function openManifest(obj)
            edit( obj.ManifestFilePath )
        end

        % Change current directory to the Add-On installation folder
        function cdInstallationFolder(obj)
            cd(obj.InstallationFolder)
        end

        function numAddonsInstalled = installMissingAddons(obj, modules)
        % installMissingAddons - Install add-ons that are not installed.
            arguments
                obj (1,1) nansen.config.addons.AddonManager
                modules (1,:) string = string.empty
            end

            obj.refreshManagedAddons("SelectedModules", modules);
            addonEntries = obj.getManagedAddonsForModules(modules);

            numAddonsInstalled = 0;
            for i = 1:numel(addonEntries)
                if addonEntries(i).IsInstalled
                    continue
                end
                % downloadAddon swallows install errors as warnings; the
                % AddonList entry is only marked IsInstalled on success,
                % so we read it back to count actual successes.
                addonIdx = obj.getAddonIndex(addonEntries(i).Name);
                obj.downloadAddon(addonIdx)
                if obj.AddonList(addonIdx).IsInstalled
                    numAddonsInstalled = numAddonsInstalled + 1;
                end
            end
            obj.saveAddonList()

            if ~nargout
                clear numAddonsInstalled
            end
        end

        function updateAddons(obj, modules)
        % updateAddons - Update tracked installed addons.
            arguments
                obj (1,1) nansen.config.addons.AddonManager
                modules (1,:) string = string.empty
            end

            obj.refreshManagedAddons("SelectedModules", modules);
            addonEntries = obj.getManagedAddonsForModules(modules);

            for i = 1:numel(addonEntries)
                addonEntry = addonEntries(i);
                if addonEntry.IsInstalled
                    obj.downloadAddon(addonEntry.Name, true)
                end
            end
            obj.saveAddonList()
        end

        function saveAddonList(obj)
        %saveAddonList Save the addon list as JSON.
            savedData = struct();
            savedData.type = 'Nansen Configuration: List of Installed Addons';
            savedData.description = 'Installed addons tracked by NANSEN AddonManager';
            savedData.AddonList = obj.AddonList;
            jsonText = jsonencode(savedData, 'PrettyPrint', true);
            nansenDirectory = fileparts(obj.ManifestFilePath);
            if ~isfolder(nansenDirectory); mkdir(nansenDirectory); end
            fileIdentifier = fopen(obj.ManifestFilePath, 'w');
            assert(fileIdentifier ~= -1, ...
                'NANSEN:AddonManager:SaveFailed', ...
                'Could not open addon manifest for writing: %s', ...
                obj.ManifestFilePath)
            closeFile = onCleanup(@() fclose(fileIdentifier));
            fwrite(fileIdentifier, jsonText, 'char');

            obj.markClean()
        end

        function refreshManagedAddons(obj, options)
        %refreshManagedAddons Sync addon list with resolved dependencies.
            arguments
                obj
                options.SelectedModules (1,:) string = string.empty
                options.ManifestPaths (1,:) string = string.empty
            end

            resolveOptions = { ...
                "DependencyTypes", "community-toolbox", ...
                "SelectedModules", options.SelectedModules, ...
                "TrackedAddons", obj.AddonList};
            if ~isempty(options.ManifestPaths)
                resolveOptions = [resolveOptions, ...
                    {"ManifestPaths"}, {options.ManifestPaths}];
            end
            resolvedRequirements = nansen.internal.dependencies.resolveRequirements( ...
                resolveOptions{:});

            obj.mergeRequirementsIntoAddonList(resolvedRequirements);
            obj.checkAddonDuplication()
        end

        % Open UI dialog for user to locate Add-On
        function tf = locateAddonPath(obj, addonName)
        %locateAddonPath Manually locate an addon folder on disk.
            tf = false;
            addonIdx = obj.getAddonIndex(addonName);
            pkgInstallationDir = uigetdir();
            if pkgInstallationDir == 0
                return
            end
            obj.AddonList(addonIdx).IsInstalled = true;
            obj.AddonList(addonIdx).DateInstalled = char(datetime("now"));
            obj.AddonList(addonIdx).FilePath = pkgInstallationDir;
            obj.AddonList(addonIdx).InstallationType = 'folder';
            obj.AddonList(addonIdx).ToolboxIdentifier = '';
            obj.addAddonToMatlabPath(addonIdx)
            obj.AddonList(addonIdx).IsOnPath = true;
            obj.saveAddonList();
            tf = true;
        end

        % Download (and install) specified Add-On
        function downloadAddon(obj, addonIdx, updateFlag, throwErrorIfFails)
        %downloadAddon Install an addon via matbox.
            if nargin < 3; updateFlag = false; end
            if nargin < 4; throwErrorIfFails = false; end
            if ischar(updateFlag) && strcmp(updateFlag, 'update')
                updateFlag = true;
            end

            addonIdx = obj.getAddonIndex(addonIdx);
            addonEntry = obj.AddonList(addonIdx);
            sourceUri = string(addonEntry.Source);

            try
                installResult = obj.installViaMatbox( ...
                    sourceUri, updateFlag);
            catch ME
                if throwErrorIfFails
                    rethrow(ME)
                else
                    warning('NANSEN:AddonManager:InstallFailed', ...
                        'Failed to install %s: %s', addonEntry.Name, ME.message)
                    return
                end
            end

            obj.AddonList(addonIdx).FilePath = obj.getCharOrEmpty(installResult.FilePath);
            obj.AddonList(addonIdx).InstallationType = char(installResult.InstallationType);
            obj.AddonList(addonIdx).ToolboxIdentifier = char(installResult.ToolboxIdentifier);
            obj.AddonList(addonIdx).IsInstalled = true;
            obj.AddonList(addonIdx).IsOnPath = true;
            obj.AddonList(addonIdx).DateInstalled = char(datetime("now"));
            obj.addAddonToMatlabPath(addonIdx)
            obj.markDirty()

            % Run named setup function if specified (matbox only runs setup.m)
            try
                if ~isempty(addonEntry.SetupFunctionName)
                    feval(addonEntry.SetupFunctionName)
                end
            catch MECause
                if throwErrorIfFails
                    ME = MException("Nansen:AddonInstallFailed", ...
                        'Setup of the toolbox %s failed.', addonEntry.Name);
                    ME = ME.addCause(MECause);
                    throw(ME)
                else
                    warning('Setup of the toolbox %s failed with the following error:', addonEntry.Name)
                    disp(getReport(MECause, 'extended'))
                end
            end
        end

        % Check if specified Add-On is installed
        function tf = isAddonInstalled(obj, addonName)
        %isAddonInstalled Check if addon is tracked as installed.
            
            tf = false;
            if any(strcmpi({obj.AddonList.Name}, addonName))
                addonIndex = obj.getAddonIndex(addonName);
                tf = obj.AddonList(addonIndex).IsInstalled;
            end
        end

        function ensureAddonDependenciesOnPath(obj)
        %ensureAddonDependenciesOnPath Activate all tracked installed addons.
            for i = 1:numel(obj.AddonList)
                if obj.AddonList(i).IsInstalled
                    obj.addAddonToMatlabPath(i)
                    obj.AddonList(i).IsOnPath = obj.isAddonOnPath(obj.AddonList(i));
                end
            end
        end

        function markDirty(obj)
            obj.IsDirty = true;
        end

        function markClean(obj)
            obj.IsDirty = false;
        end
    end
    
    methods % Set/get
        function managedAddons = get.ManagedAddons(obj)
            T = struct2table(obj.AddonList);
            numberColumn = table((1:size(T,1))', 'VariableNames', {'Num'});
            managedAddons = [numberColumn T];
            
            % Enrich name with link to online documentation if present 
            for i = 1:height(managedAddons)
                if ~isempty(managedAddons{i, 'DocsSource'}{1})
                    name = nansen.internal.utility.createCommandWindowWebLink(...
                        managedAddons{i, 'DocsSource'}{1}, managedAddons{i, 'Name'}{1});
                    managedAddons{i, 'Name'} = {name};
                end
            end

            managedAddons = removevars(managedAddons, ...
                ["Source", "DocsSource", "SetupFunctionName", "InstallCheck", ...
                "ToolboxIdentifier", "HasMultipleInstancesOnPath"]);
            managedAddons.Name = string(managedAddons.Name);
            managedAddons.Description = string(managedAddons.Description);
            managedAddons = movevars(managedAddons, "IsOnPath", "After", "IsInstalled");
            managedAddons = movevars(managedAddons, "Description", "After", "IsOnPath");
        end

        function addonEntries = getManagedAddonsForModules(obj, modules)
        %getManagedAddonsForModules Return managed addons relevant for selected modules.
            arguments
                obj (1,1) nansen.config.addons.AddonManager
                modules (1,:) string = string.empty
            end
            
            resolvedRequirements = nansen.internal.dependencies.resolveRequirements( ...
                "DependencyTypes", "community-toolbox", ...
                "SelectedModules", modules, ...
                "TrackedAddons", obj.AddonList);
            addonNames = string({resolvedRequirements.Name});
            isMatch = ismember(string({obj.AddonList.Name}), addonNames);
            addonEntries = obj.AddonList(isMatch);
        end
    end

    methods (Hidden)
        function downloadAndInstallMatBox(obj)
            installResult = obj.createInstallResult("", "folder", "");

            obj.ensureAddonDefinitionExists('MatBox')

            if ~exist('+matbox/installRequirements', 'file')
                sourceFile = 'https://raw.githubusercontent.com/ehennestad/matbox-actions/refs/heads/main/install-matbox/installMatBox.m';
                filePath = websave('installMatBox.m', sourceFile);
                [installationFolder, installationMethod] = installMatBox('commit');
                installResult = obj.createInstallResult(installationFolder, installationMethod, "");
                rehash()
                delete(filePath);
            else
                matboxFunctionPath = which('matbox.VersionNumber');
                if ~isempty(matboxFunctionPath)
                    matboxRootFolder = fileparts(fileparts(matboxFunctionPath));
                    installResult = obj.createInstallResult(matboxRootFolder, "folder", "");
                end
            end

            addonIdx = obj.getAddonIndex('MatBox');
            addonEntry = obj.AddonList(addonIdx);

            hasChanges = false;
            filePath = obj.getCharOrEmpty(installResult.FilePath);
            installationType = obj.getCharOrEmpty(installResult.InstallationType);

            if ~addonEntry.IsInstalled
                obj.AddonList(addonIdx).IsInstalled = true;
                hasChanges = true;
            end
            if ~addonEntry.IsOnPath
                obj.AddonList(addonIdx).IsOnPath = true;
                hasChanges = true;
            end
            if ~isempty(filePath) && ~strcmp(addonEntry.FilePath, filePath)
                obj.AddonList(addonIdx).FilePath = filePath;
                hasChanges = true;
            end
            if ~isempty(installationType) && ~strcmp(addonEntry.InstallationType, installationType)
                obj.AddonList(addonIdx).InstallationType = installationType;
                hasChanges = true;
            end
            if ~strcmp(addonEntry.ToolboxIdentifier, '')
                obj.AddonList(addonIdx).ToolboxIdentifier = '';
                hasChanges = true;
            end
            if ~addonEntry.IsInstalled || ...
                    (ischar(addonEntry.DateInstalled) && strcmp(addonEntry.DateInstalled, 'N/A'))
                obj.AddonList(addonIdx).DateInstalled = char(datetime("now"));
                hasChanges = true;
            end

            if hasChanges
                obj.markDirty()
                obj.saveAddonList()
            end
        end
    
        function viewFullAddonListAsTable(obj)
            disp( struct2table(obj.AddonList) )
        end
    end

    methods

        function addAddonToMatlabPath(obj, addonIdx)
        %addAddonToMatlabPath Activate an installed addon for this MATLAB session.
            addonIdx = obj.getAddonIndex(addonIdx);
            addonEntry = obj.AddonList(addonIdx);
            installationType = string(addonEntry.InstallationType);

            if installationType == "mltbx"
                obj.enableToolboxAddon(addonEntry)
                return
            end

            addonFilePath = addonEntry.FilePath;
            if isempty(addonFilePath) || ~isfolder(addonFilePath)
                return
            end
            pathList = genpath(addonFilePath);
            pathListCell = strsplit(pathList, pathsep);
            keep = ~contains(pathListCell, '.git');
            pathListCell = pathListCell(keep);
            pathListNoGit = strjoin(pathListCell, pathsep);
            addpath(pathListNoGit);
        end
    end

    methods (Access = private)

        function loadAddonManifest(obj)
        %loadAddonManifest - Load addon manifest from file.
            wasMigrated = false;
            if isfile(obj.ManifestFilePath)
                jsonText = fileread(obj.ManifestFilePath);
                savedData = jsondecode(jsonText);
                addonList = savedData.AddonList;
                if iscell(addonList)
                    addonList = [addonList{:}];
                end
            else
                [addonList, wasMigrated] = obj.tryMigrateFromLegacyLocation();
            end
            obj.AddonList = addonList;

            if wasMigrated
                obj.saveAddonList()
            end
        end

        function mergeRequirementsIntoAddonList(obj, resolvedRequirements)
        % mergeRequirementsIntoAddonList - Sync addon list with resolved dependencies.
            if nargin < 2
                resolvedRequirements = nansen.internal.dependencies.resolveRequirements( ...
                    "DependencyTypes", "community-toolbox");
            end

            if isempty(resolvedRequirements)
                return
            end

            resolvedNames = string({resolvedRequirements.Name});
            currentAddonNames = string({obj.AddonList.Name});

            for idx = 1:numel(resolvedRequirements)
                entry = resolvedRequirements(idx);
                addonIdx = find(currentAddonNames == resolvedNames(idx), 1);

                if isempty(addonIdx)
                    addonIdx = numel(obj.AddonList) + 1;
                    obj.AddonList(addonIdx) = obj.createAddonEntry(entry);
                    currentAddonNames(end+1) = resolvedNames(idx); %#ok<AGROW>
                end

                obj.AddonList(addonIdx).Name = char(entry.Name);
                obj.AddonList(addonIdx).IsRequired = entry.RequirementLevel == "required";
                obj.AddonList(addonIdx).Description = char(entry.Description);
                obj.AddonList(addonIdx).Source = char(entry.Source);
                obj.AddonList(addonIdx).DocsSource = char(entry.DocsSource);
                obj.AddonList(addonIdx).SetupFunctionName = char(entry.SetupHook);
                obj.AddonList(addonIdx).InstallCheck = char(entry.InstallCheck);
                obj.AddonList(addonIdx).IsInstalled = entry.IsInstalled;
                obj.AddonList(addonIdx).IsOnPath = entry.IsOnPath;

                if obj.AddonList(addonIdx).IsInstalled && strcmp(obj.AddonList(addonIdx).DateInstalled, 'N/A')
                    obj.AddonList(addonIdx).DateInstalled = char(datetime("now"));
                end
            end
        end

        function checkAddonDuplication(obj)
        %checkAddonDuplication Detect addons with multiple path locations.
            for i = 1:numel(obj.AddonList)
                probeName = obj.AddonList(i).InstallCheck;
                obj.AddonList(i).HasMultipleInstancesOnPath = false;
                if isempty(probeName); continue; end
                pathStr = which(probeName, '-all');
                if isa(pathStr, 'cell') && numel(pathStr) > 1
                    obj.AddonList(i).HasMultipleInstancesOnPath = true;
                end
            end
        end

        function addonIdx = getAddonIndex(obj, addonIdx)
        %getAddonIndex Get index of addon by name or pass through numeric index.
            if ischar(addonIdx) || isstring(addonIdx)
                addonIdx = find(strcmpi({obj.AddonList.Name}, addonIdx));
            end
            if isempty(addonIdx)
                error('NANSEN:AddonManager:NotFound', ...
                    'Addon was not found in list.')
            end
        end

        function installResult = installViaMatbox(obj, sourceUri, doUpdate)
        %installViaMatbox Delegate installation to matbox based on URI type.

            installResult = matbox.setup.installFromSourceUri( ...
                sourceUri, ...
                "InstallationLocation", obj.InstallationFolder, ...
                "AddToPath", true, ...
                "Update", doUpdate, ...
                "Verbose", true, ...
                "AgreeToLicense", true);

            requiredFields = ["FilePath", "InstallationType", "ToolboxIdentifier"];
            missingFields = requiredFields(~isfield(installResult, requiredFields));
            if ~isempty(missingFields)
                error("NANSEN:AddonManager:UnexpectedInstallResult", ...
                    "matbox.setup.installFromSourceUri returned a result without the expected fields: %s", ...
                    strjoin(missingFields, ", "));
            end
        end

        function ensureAddonDefinitionExists(obj, addonName)
        %ensureAddonDefinitionExists Populate core addon definitions if needed.
            if any(strcmpi({obj.AddonList.Name}, addonName))
                return
            end

            obj.refreshManagedAddons();
        end
    
        function tf = isSameFolder(obj, folderB)
            folderA = nansen.internal.utility.stripTrailingFilesep(obj.InstallationFolder);
            folderB = nansen.internal.utility.stripTrailingFilesep(folderB);

            if ispc
                tf = strcmpi(folderA, folderB);
            else
                tf = strcmp(folderA, folderB);
            end
        end
    end

    methods (Access = private)
        function addonEntry = createAddonEntry(obj, entry)
            addonEntry = obj.getDefaultAddonEntry();

            addonEntry.Name = char(entry.Name);
            addonEntry.IsRequired = entry.RequirementLevel == "required";
            addonEntry.IsInstalled = entry.IsInstalled;
            addonEntry.IsOnPath = entry.IsOnPath;
            addonEntry.DateInstalled = 'N/A';
            addonEntry.FilePath = '';
            addonEntry.Description = char(entry.Description);
            addonEntry.Source = char(entry.Source);
            addonEntry.DocsSource = char(entry.DocsSource);
            addonEntry.SetupFunctionName = char(entry.SetupHook);
            addonEntry.InstallCheck = char(entry.InstallCheck);
            addonEntry.InstallationType = '';
            addonEntry.ToolboxIdentifier = '';
            addonEntry.HasMultipleInstancesOnPath = false;
            
            if entry.IsInstalled
                addonEntry.DateInstalled = char(datetime("now"));
            end
        end

        function tf = isAddonOnPath(~, addonEntry)
            tf = false;
            if ~isempty(addonEntry.InstallCheck)
                tf = ~isempty(which(addonEntry.InstallCheck));
            end
        end

        function enableToolboxAddon(~, addonEntry)
            if ~isempty(addonEntry.InstallCheck) && ~isempty(which(addonEntry.InstallCheck))
                return
            end
            if ~isempty(addonEntry.ToolboxIdentifier)
                try
                    matlab.addons.enableAddon(addonEntry.ToolboxIdentifier)
                    return
                catch
                end
            end
            if ~isempty(addonEntry.Name)
                matlab.addons.enableAddon(addonEntry.Name)
            end
        end
    end

    methods (Static, Hidden)
        function checkIfAddonsAreOnPath() % Todo: Needs improvement, not urgent
        %checkIfAddonsAreOnPath Prompt user to add missing addon folders to path.
            addonDir = nansen.config.addons.getDefaultAddonFolder();
            subfolders = utility.path.listSubDir(addonDir, '', {}, 2);
            isOnPath = true(size(subfolders));
            if ~isempty(subfolders)
                for i = 1:numel(subfolders)
                    if ~contains(path, subfolders{i})
                        isOnPath(i) = false;
                    end
                end
            end
            if any(~isOnPath)
                subfoldersNotOnPath = subfolders(~isOnPath);
                [~, addonNames] = fileparts(subfoldersNotOnPath);
                msg = sprintf( ...
                    "The following add-ons were not present on the MATLAB path:\n\n%s\n\nDo you want to add them now?", ...
                    strjoin(addonNames, newline));
                answer = questdlg(msg, 'Update MATLAB path?');
                if strcmp(answer, 'Yes')
                    for i = 1:numel(subfoldersNotOnPath)
                        addpath(genpath(subfoldersNotOnPath{i}))
                    end
                    savepath()
                end
            end
        end
    end

    methods (Static, Access = private)
        function addonEntry = getDefaultAddonEntry()
            addonEntry = nansen.config.addons.AddonManager.DefaultAddonEntry;
        end
        
        function addonEntry = initializeAddonList()
        %initializeAddonList Create an empty struct with addon fields.
            addonEntry = nansen.config.addons.AddonManager.DefaultAddonEntry;
            addonEntry(1) = [];
        end
        
        function newAddonList = migrateLegacyAddonList(oldAddonList)
        %migrateLegacyAddonList Remap legacy addon struct fields to new names.
        %   Handles old addon lists that have DownloadUrl, WebUrl,
        %   SetupFileName, FunctionName fields.
            
            import nansen.config.addons.AddonManager

            newAddonList = AddonManager.initializeAddonList();
            if isempty(oldAddonList); return; end

            if isfield(oldAddonList, 'DownloadUrl') && ~isfield(oldAddonList, 'Source')
                
                for i = 1:numel(oldAddonList)
                    newAddonList(i) = AddonManager.getDefaultAddonEntry();
                                        
                    newAddonList(i).Name = oldAddonList(i).Name;
                    newAddonList(i).Description = oldAddonList(i).Description;
                    newAddonList(i).Source = oldAddonList(i).DownloadUrl;
                    newAddonList(i).DocsSource = oldAddonList(i).WebUrl;
                    newAddonList(i).SetupFunctionName = oldAddonList(i).SetupFileName;
                    newAddonList(i).InstallCheck = oldAddonList(i).FunctionName;
                    newAddonList(i).IsInstalled = oldAddonList(i).IsInstalled;
                    newAddonList(i).DateInstalled = oldAddonList(i).DateInstalled;
                    newAddonList(i).FilePath = oldAddonList(i).FilePath;

                    if ~isempty(oldAddonList(i).FilePath) && isfolder(oldAddonList(i).FilePath)
                        newAddonList(i).InstallationType = 'folder';
                    end
                end
            else
                newAddonList = oldAddonList;
            end
        end

        function [addonList, wasMigrated] = tryMigrateFromLegacyLocation()
        %tryMigrateFromLegacyLocation Migrate addon list from legacy .mat location.
            wasMigrated = false;
            legacyMatPath = fullfile(prefdir, 'Nansen', 'default', 'settings', 'installed_addons.mat');
            if isfile(legacyMatPath)
                loadedData = load(legacyMatPath);
                addonList = loadedData.AddonList;
                addonList = nansen.config.addons.AddonManager.migrateLegacyAddonList(addonList);
                wasMigrated = true;
            else
                addonList = nansen.config.addons.AddonManager.initializeAddonList();
            end
        end

        function pathStr = getDefaultInstallationDirLegacy()
        % Note: This method will be removed in a future version.
            pathStr = fullfile(nansen.rootpath, 'external');
        end
    end

    methods (Static, Access = private)

        function installResult = createInstallResult(filePath, installationType, toolboxIdentifier)
            if nargin < 3
                toolboxIdentifier = "";
            end

            filePath = string(filePath);
            installationType = string(installationType);
            toolboxIdentifier = string(toolboxIdentifier);

            if isempty(filePath) || any(ismissing(filePath))
                filePath = "";
            end
            if isempty(installationType) || any(ismissing(installationType))
                installationType = "folder";
            end
            if isempty(toolboxIdentifier) || any(ismissing(toolboxIdentifier))
                toolboxIdentifier = "";
            end

            installResult = struct( ...
                'FilePath', filePath, ...
                'InstallationType', installationType, ...
                'ToolboxIdentifier', toolboxIdentifier);
        end

        function value = getCharOrEmpty(stringValue)
            stringValue = string(stringValue);
            if isempty(stringValue) || any(ismissing(stringValue))
                value = '';
            else
                value = char(stringValue);
            end
        end

        function folderPath = stripTrailingFilesep(folderPath)
            folderPath = char(folderPath);
            while numel(folderPath) > 1 && endsWith(folderPath, filesep)
                folderPath = folderPath(1:end-1);
            end
        end
    end

    methods (Hidden) % For backwards compatibility. Will be removed in future
        moveExternalToolboxes(obj) % Method in separate file
    end

    methods (Static, Hidden) % For backwards compatibility. Will be removed in future
        function tf = existExternalToolboxInRepository()
        % Note: This method will be removed in a future version.
            rootDir = fullfile(nansen.rootpath, 'external');
            tf = isfolder(fullfile(rootDir, 'general_toolboxes')) || ...
                    isfolder(fullfile(rootDir, 'neuroscience_toolboxes'));
        end
    end
end
