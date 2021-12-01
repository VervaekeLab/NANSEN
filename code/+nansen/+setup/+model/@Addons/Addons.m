classdef Addons < handle
    %ADDONS A simple addon manager for managing a custom list of addons
    %   Provides an interface for downloading and adding addons/toolboxes
    %   to the matlab path. Addons are specified in a separate function
    %   and this class provides several methods for managing these addons.
    
    
    
    % TODOS:
    % [X] Save addon list
    % [x] System for adding addons to path on startup
    % [ ] Make another class for addons. 
    % [ ] Rename to addon manager
    % [ ] Add option for setting a custom installation dir
    % [ ] File with list of addons should be saved based on which software
    %     it belongs to. Either use subclassing, or make a way to use access 
    %     a settings file by a keyword or something similar.
    % [ ] Better warning/resolving when addons are duplicated...
    
    % [ ] Use matlab.addons.install(filename) for matlab toolbox files.
    
    
    % QUESTIONS:
    %   - Use gitmodules??
    %   - Implement better git functionality, i.e version tracking
    
    
    
    properties (Constant, Hidden)
        
        % A list of fields that are relevant for each addon entry
        % Todo: make into a separate class...
        addonFields = {...  
            'Name', ...             % Name of addon
            'IsRequired', ...       % Whether addon is required or optional
            'IsInstalled', ...
            'DateInstalled', ...
            'FilePath', ...
            'WebSource', ...
            'WebUrl', ...
            'DownloadUrl', ...
            'HasSetupFile', ...
            'SetupFileName', ...
            'FunctionName', ...
            'AddToPathOnInit', ...
            'IsDoubleInstalled'}
    
    end
    
    properties
        InstallationDir char = ''   % Path where addons should be installed
        UseGit logical = false      % Whether to use git for downloads and updates
        AddonList struct = struct() % List of addons (table or struct array)
    
        IsDirty
    end
    
    properties (SetAccess = private)
        AddonDefinitionsPath
    end
    
    
    methods
        
        function obj = Addons()
        %ADDONS Construct an instance of this class
        
            % Create a addon manager instance. Provide methods for
            % installing addons
            
            % Assign the path to the directory where addons are saved
            obj.InstallationDir = obj.getDefaultInstallationDir();
            
            % Get path where list of previously installed addons are saved
            obj.AddonDefinitionsPath = obj.getPathForAddonList;
            
            % Load addon list (list is initialized if it does not exist)
            obj.loadAddonList()
            
            % Add previously installed addons to path if they are not already there.
            obj.updateSearchPath()
        
            % Check if there are multiple versions of addons on the matlab
            % search path.
            obj.checkAddonDuplication()
            
        end
        
    end
    
    methods
        
        function listAddons(obj)
        %listAddons Display a table of addons
            
            T = struct2table(obj.AddonList);
            
            % Add a column with index numbers.
            numberColumn = table((1:size(T,1))', 'VariableNames', {'Num'});
            T = [numberColumn T];
            
            % Display table
            disp(T)
        end
        
        function loadAddonList(obj)
        % loadAddonList Load list (csv or xml) with required/supported addons
        
            % Load list
            if isfile(obj.AddonDefinitionsPath)
                S = load(obj.AddonDefinitionsPath);
                addonList = S.AddonList;
            else
                addonList = obj.initializeAddonList(); % init to empty struct
            end
            
            addonList = obj.updateAddonList(addonList);
            
            % Assign to AddonList property
            obj.AddonList = addonList;
            
        end
        
        function saveAddonList(obj)
        %saveAddonList Sve the list of addons to file.
        
            S.AddonList = obj.AddonList; %#ok<STRNU>
            save(obj.AddonDefinitionsPath, '-struct', 'S')
            
        end
        
        function S = updateAddonList(~, S)
        %updateAddonList Compare current with default 
        %   (in case defaults have been updated)
        
        %   %todo: rename
        
            % Get package list
            defaultAddonList = nansen.setup.defaults.getAddonList();
            
            %numAddons = numel(defaultAddonList);
            
            defaultAddonNames = {defaultAddonList.Name};
            currentAddonNames = {S.Name};
            
            isNew = ~ismember(defaultAddonNames, currentAddonNames);
            
            newAddons = find(isNew);
            fieldNames = fieldnames(defaultAddonList);
                   
            % If some addons are present in default addon list and not in
            % current addon list, add from default to current.
            for iAddon = newAddons
                next = numel(S) + 1;
                
                for jField = 1:numel(fieldNames)
                    thisField = fieldNames{jField};
                    S(next).(thisField) = defaultAddonList(iAddon).(thisField);
                end
                
                % Check if addon is found on matlab's path and update
                % IsInstalled flag
                if ismember(exist(S(next).FunctionName), [2,8])
                    S(next).IsInstalled = true;
                    S(next).DateInstalled = datestr(now);
                else
                    S(next).IsInstalled = false;
                    S(next).DateInstalled = 'N/A';
                end
                
                % Set this flag to false. This should change if an addon is
                % installed, but not saved to the matlab search path.
                S(next).AddToPathOnInit = false;

                
            end
            
        end
        
        function tf = browseAddonPath(obj, addonName)
            
            tf = false;
            addonIdx = obj.getAddonIndex(addonName);

            % Open path dialog to locate folderpath for addon
            pkgInstallationDir = uigetdir();
            
            if pkgInstallationDir == 0
                return
            end
            
            obj.AddonList(addonIdx).IsInstalled = true;
            obj.AddonList(addonIdx).DateInstalled = datestr(now);
            obj.AddonList(addonIdx).FilePath = pkgInstallationDir;
            
            % Addon is added using this addon manager. Addon should 
            % therefore be added to the Matlab search path when this
            % class is initialized. (assume it should not permanently be 
            % saved to the search path)
            obj.AddonList(addonIdx).AddToPathOnInit = true;
            
            tf = true;
        end
        
        function downloadAddon(obj, addonIdx, updateFlag)
        %downloadAddon Download addon to a specified addon folder
        
            if nargin < 3; updateFlag = false; end
            
            if isa(updateFlag, 'char') && strcmp(updateFlag, 'update')
                updateFlag = true;
            end
                
            addonIdx = obj.getAddonIndex(addonIdx);
            addonEntry = obj.AddonList(addonIdx);
            
            % Create a temporary path for storing the downloaded file.
            tempZipFilepath = [tempname '.zip'];
            
            % Download the zip-file containing the addon toolbox
            try
                tempZipFilepath = websave(tempZipFilepath, addonEntry.DownloadUrl);
            catch ME
                error(ME)
            end
            
            if updateFlag && ~isempty(addonEntry.FilePath)
                pkgInstallationDir = addonEntry.FilePath;
                rootDir = utility.path.getAncestorDir(pkgInstallationDir);
                
                % Delete current version
                rmdir(pkgInstallationDir, 's')
            else
                % Unzip the file in the package directory
                rootDir = obj.InstallationDir;
                pkgInstallationDir = fullfile(rootDir, addonEntry.Name);
            end
            
            unzip(tempZipFilepath, pkgInstallationDir);
            
            % Delete the temp zip file
            delete(tempZipFilepath)
            
            % Github packages unzips to a new folder within the created
            % folder. Move it up one level.
            if strcmp(addonEntry.Source, 'Github')
                
                % Find the repository folder
                L = dir(pkgInstallationDir);
                L = L(~strncmp({L.name}, '.', 1));
                
                % Move folder up one level
                oldDir = fullfile(pkgInstallationDir, L.name);
                newDir = fullfile(rootDir, L.name);
                movefile(oldDir, newDir)
                rmdir(pkgInstallationDir)
                
                % Remove the master postfix from foldername
                newName = strrep(L.name, '-master', '');
                renamedDir = fullfile(rootDir, newName);
                movefile(newDir, renamedDir)
                
                pkgInstallationDir = renamedDir;
            end
            
            obj.AddonList(addonIdx).IsInstalled = true;
            obj.AddonList(addonIdx).DateInstalled = datestr(now);
            obj.AddonList(addonIdx).FilePath = pkgInstallationDir;
            
            % Addon is added using this addon manager. Addon should 
            % therefore be added to the Matlab search path when this
            % class is initialized. (assume it should not permanently be 
            % saved to the search path)
            obj.AddonList(addonIdx).AddToPathOnInit = true;
           
            obj.markDirty()
            
            
            % Special case... Need to add something to the javapath
            if strcmp(obj.AddonList(addonIdx).Name, 'Widgets Toolbox')
                jarFilePath = fullfile(pkgInstallationDir, 'resource', 'MathWorksConsultingWidgets.jar');
                success = nansen.setup.model.Addons.addStaticJavaPath(jarFilePath); 
                javaclasspath( jarFilePath ) %Temp add to dynamic path...
            end
            
        end
        
        function updateSearchPath(obj)
        %updateSearchPath Add addons to the search path in the current matlab session
        
            for i = 1:numel(obj.AddonList)
                % Only add those who have filepath assigned (those are added from this interface)
                if obj.AddonList(i).AddToPathOnInit
                    obj.addAddonToMatlabPath(i)
                end
                
            end
            
        end
        
        function addAddonToMatlabPath(obj, addonIdx)
            
            addonIdx = obj.getAddonIndex(addonIdx);
            pathList = genpath(obj.AddonList(addonIdx).FilePath);
            
            % Remove all .git subfolders from this list
            pathListCell = strsplit(pathList, ':');
            keep = ~contains(pathListCell, '.git');
            pathListCell = pathListCell(keep);
            pathListNoGit = strjoin(pathListCell, ':');

            % Add all remaining folders to path.
            addpath(pathListNoGit); 
            
        end
        
        function addAllToMatlabPath(obj)
            
            for i = 1:numel(obj.AddonList)
                
                % Only add those who have filepath assigned (those are added from this interface)
                if ~isempty(obj.AddonList(i).FilePath)
                    obj.addAddonToMatlabPath(i)
                end
                
            end
            
        end
        
        function restoreAddToPathOnInitFlags(obj)
            
            for i = 1:numel(obj.AddonList)
                
                % Only add those who have filepath assigned (those are added from this interface)
                if obj.AddonList(i).IsInstalled
                    if obj.AddonList(i).AddToPathOnInit
                        obj.AddonList(i).AddToPathOnInit = false; 
                    end
                end
                
            end
            
            obj.saveAddonList()
            
        end
        
        function checkAddonDuplication(obj)

            for i = 1:numel(obj.AddonList)
                
                pathStr = which( obj.AddonList(i).FunctionName, '-all');
                
                if isa(pathStr, 'cell') && numel(pathStr) > 1
                    obj.AddonList(i).IsDoubleInstalled = true;
                end
                
            end
            
        end
        
        % Not implemented yet. Future todo
        function runAddonSetup(obj, addonIdx)
            
        end
        
        % Not implemented:
        function TF = isAddonInstalled(obj, addonName)
            
            % Find addon in list of addons.
            
            
            % Add a switch block to handle different addons.
        
            % Todo Question:
            %   Should we look for whether name of package is present?
            %   Or, look for a function in the package and check if it is
            %   on path...?
            
            
            switch obj.AddonList(ind).AddonName
                
            end

        end
        
        % Not implemented:
        function TF = isAddonUpToDate(obj)
        %isAddonRecent 
        
            % Check if version is latest...?
        
            % Not urgent
            
        end
        
        function markDirty(obj)
            obj.IsDirty = true;
        end
        
        function markClean(obj)
            obj.IsDirty = false;
        end
    end
    
    methods (Access = protected)
        
        function addonIdx = getAddonIndex(obj, addonIdx)
        %getAddonIndex Get index (number) of addon in list given addon name  
            
            if isa(addonIdx, 'char')
                addonIdx = strcmpi({obj.AddonList.Name}, addonIdx);
            end
            
            if isempty(addonIdx)
                error('Something went wrong, addon was not found in list.')
            end
            
        end
    
    end
    
    methods (Hidden, Access = protected) 
               
        function pathStr = getPathForAddonList(obj)
        %getPathForAddonList Get path where local addon list is saved.
        
            %Todo: What do I call this?
            
            nansenDir = nansen.rootpath;
            rootDir = utility.path.getAncestorDir(nansenDir, 1);
            pathStr = fullfile(rootDir, '_userdata', 'settings');
            
            if ~exist(pathStr, 'dir'); mkdir(pathStr); end
            
            pathStr = fullfile(pathStr, 'installed_addons.mat');
            
        end
        
        % Following functions are not implemented
        function downloadGithubAddon(obj, addonName)
            
        end
        
        function downloadMatlabAddon(obj, addonName)
            
        end
        
        function installGithubAddon(obj, addonName)
            
        end
        
        function installMatlabAddon(obj, addonName)
            
        end
        
    end
    
    methods (Static)
        
        function S = initializeAddonList()
        %initializeAddonList Create an empty struct with addon fields.
        
            names = nansen.setup.model.Addons.addonFields;
            values = repmat({{}}, size(names));
            
            structInit = [names; values];
            
            S = struct(structInit{:});
            
        end
        
        function pathStr = getDefaultInstallationDir()
        %getDefaultInstallationDir Get path to default directory for
        %   installing addons
        
            % Assign Installation dir
            nansenDir = nansen.rootpath;
            rootDir = utility.path.getAncestorDir(nansenDir, 1);
            pathStr = fullfile(rootDir, 'toolboxes');
            
        end
        
        function doneTF = addStaticJavaPath(javapath)

            doneTF = false; 

            savedir = prefdir;

            filepath = fullfile(savedir, 'javaclasspath.txt');

            if ~exist(filepath, 'file')
                fid = fopen(filepath, 'w', 'n', 'UTF-8');
            else
                fid = fopen(filepath, 'a', 'n', 'UTF-8');
            end
            
            fprintf(fid, '%s', javapath);
            
            status = fclose(fid);
            if status == 0
                doneTF = true;
            end

        end
    end

end

