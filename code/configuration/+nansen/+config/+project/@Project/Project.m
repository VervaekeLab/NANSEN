classdef Project < nansen.module.Module
%Project A class to represent a Project

    % Work in progress.
    
    % This object should reflect the content of a project folder and have
    % methods for interacting with data in the project folder.
    
    % Todo : 
    %   [ ] Clean up object display
    %   [ ] Define preferences explicitly somehow.
    %   [ ] Consider whether project folder should be dependent, i.e if it
    %       is changed from project manager, instances need to be updated.
    %   [ ] Should there be a project preference whether to save task lists
    %       for a project?
    
    properties % Inherited from module
        %Name                        % Name of the project
    end

    properties
        IncludedModules nansen.module.Module
    end
    
    properties (SetAccess = private)
        FolderPath char             % Path to the project folder
    end
    
    properties (Dependent)
        Preferences                 % Preferences for the project
        MetatableCatalog            % Catalog of metadata tables
        MetatableViewCatalog        % Catalog of metadata table views
        DataLocationModel           % Data location model for the project
        VariableModel               % Variable model for the project
    end

    properties (Access = private)
        PackageName                 % Name of matlab package folder for the project
    end
    
    properties (Access = private)
        MetatableCatalog_   % internal store if catalog is already loaded. However, this would not be up to date it the catalog is changed. Think it is better that this is just a dependent property... 
    end

    properties (Constant, Hidden)
        % Todo: Folder property, with subfields?
        METATABLE_FOLDER_NAME = 'Metadata Tables';
        CONFIG_FOLDER_NAME = 'Configurations'; % models
    end

    
    methods (Access = ?nansen.config.project.ProjectManager)
        function obj = Project(projectName, projectFolder)
            
            packageName = strcat('+', projectName);
            moduleFolder = fullfile(projectFolder, packageName);
            obj@nansen.module.Module(fullfile(moduleFolder, 'module.json'));
            
            obj.Name = projectName;
            obj.PackageName = strcat('+', obj.Name);
            
            obj.FolderPath = projectFolder;
            
            obj.initalizeModules()
        end
    end
    
    methods

        function initalizeModules(obj)
            
            % Todo: Get from preferences!
            baseModule = 'nansen.module.general.core';

            moduleNames = [baseModule, obj.Preferences.DataModule];
            moduleNames = unique(moduleNames, 'stable'); % Just in case...

            for i = 1:numel(moduleNames)
                moduleName = moduleNames{i};
                moduleFolder = fullfile(nansen.rootpath, 'modules');
                moduleFolder = fullfile(moduleFolder, utility.path.packagename2pathstr(moduleName));
                moduleConfigFile = fullfile(moduleFolder, 'module.json');
                module = nansen.module.Module(moduleConfigFile);
                obj.IncludedModules(end+1) = module;
            end
        end

        function initializeProjectFolder(obj)
            % Todo: Create all folders that belong to a project
            if ~isfolder(obj.FolderPath); mkdir(obj.FolderPath); end
            
            % Todo: Copy a template folder
            if ~isfolder(fullfile(obj.FolderPath, obj.METATABLE_FOLDER_NAME))
                mkdir(fullfile(obj.FolderPath, obj.METATABLE_FOLDER_NAME))
            end

            if ~isfolder(fullfile(obj.FolderPath, obj.CONFIG_FOLDER_NAME))
                mkdir(fullfile(obj.FolderPath, obj.CONFIG_FOLDER_NAME))
            end

            mkdir(fullfile(obj.FolderPath, 'Session Methods', obj.PackageName))
        end

    end

    methods (Access = protected) % Override module methods

        function fileList = listFiles(obj, itemType)
        %listFiles List files in a folder hierarchy for given item type

            fileList = listFiles@nansen.module.Module(obj, itemType);

            for i = 1:numel(obj.IncludedModules)
                fileList_ = obj.IncludedModules(i).listFiles(itemType);
                fileList = cat(1, fileList_, fileList);
            end

            % Todo: ignore files if they are present in multiple modules.
            % Compare filename?
        end
    
    end
    
    methods % TODO: implement a dataiomodel on project
        function saveData(obj, varName, data)
            filePathStr = obj.getDataFilePath(varName);
            S.(varName) = data;
            save(filePathStr, '-struct', 'S');
        end

        function data = loadData(obj, varName)
            filePathStr = obj.getDataFilePath(varName);
            S = load(filePathStr, varName);
            data = S.(varName);
        end

        function filePathStr = getDataFilePath(obj, varName)
            switch varName
                case 'MetatableColumnSettings'
                    foldername = obj.METATABLE_FOLDER_NAME;
                    folderPathStr = fullfile(obj.FolderPath, foldername);
                    filename = 'metatable_column_settings';
                case 'TaskList'
                    %folderpath = obj.CONFIG_FOLDER_NAME;
                    folderPathStr = obj.getLocalProjectFolderPath();
                    filename = 'task_list.mat';
            end

            filePathStr = fullfile(folderPathStr, filename);
        end
    end

    methods (Access = ?nansen.config.project.ProjectManager)
        
        function renameProject(obj, newName)
            
            % Change name property
            obj.Name = newName;
            obj.PackageName = strcat('+', obj.Name);
            
            % Change name of folder
            oldFolderpath = obj.FolderPath;
            newFolderpath = fullfile(fileparts(oldFolderpath), obj.Name);
            movefile(oldFolderpath, newFolderpath);
            obj.FolderPath = newFolderpath;
        end
    
    end
    
    methods % Set/get

        function preferences = get.Preferences(obj)
            filePath = fullfile(obj.FolderPath, 'nansen_project_configuration.mat');
            S = load(filePath, 'ProjectConfiguration');
            if isfield(S.ProjectConfiguration, 'Preferences')
                preferences = S.ProjectConfiguration.Preferences;
            else
                preferences = struct;
            end
        end
        function set.Preferences(obj, preferences)
            filePath = fullfile(obj.FolderPath, 'nansen_project_configuration.mat');
            S = load(filePath, 'ProjectConfiguration');
            S.ProjectConfiguration.Preferences = preferences;
            save(filePath, '-struct', 'S');
        end
        
        function metatableCatalog = get.MetatableCatalog(obj)
            filePath = obj.getCatalogPath('MetaTableCatalog');
            metatableCatalog = nansen.metadata.MetaTableCatalog(filePath);
        end
                
        function metatableCatalog = get.MetatableViewCatalog(obj)
            filePath = obj.getCatalogPath('MetatableViewCatalog');
            metatableCatalog = nansen.metadata.MetaTableCatalog(filePath);
        end
        
        function dataLocationModel = get.DataLocationModel(obj)
            filePath = obj.getCatalogPath('DataLocationModel');
            dataLocationModel = nansen.config.dloc.DataLocationModel(filePath);
        end
        
        function variableModel = get.VariableModel(obj)
            filePath = obj.getCatalogPath('VariableModel');
            variableModel = nansen.config.varmodel.VariableModel(filePath);
        end
        
    end
    
    methods (Access = private)
        
        function filePathStr = getCatalogPath(obj, catalogName)
        %getCatalogPath Get absolute path for catalog as character vector 
        
            switch catalogName
                
                case 'MetaTableCatalog'
                    foldername = obj.METATABLE_FOLDER_NAME;
                    filename = 'metatable_catalog.mat';
                                    
                case 'MetatableColumnSettingsCatalog'
                    foldername = obj.METATABLE_FOLDER_NAME;
                    filename = 'metatable_column_settings.mat';
                    
                case 'DataLocationModel'
                    foldername = obj.CONFIG_FOLDER_NAME;
                    filename = 'datalocation_settings.mat';
                    
                case 'VariableModel'
                    foldername = obj.CONFIG_FOLDER_NAME;
                    filename = 'filepath_settings.mat';                    
            end
            
            folderPathStr = fullfile(obj.FolderPath, foldername);
            filePathStr = fullfile(folderPathStr, filename);
        end
        
        function folderPath = getLocalProjectFolderPath(obj)

            localProjectPath = fullfile(nansen.rootpath, '_userdata', 'projects');
            
            folderPath = fullfile(localProjectPath, obj.Name);
            if ~exist(folderPath, 'dir'); mkdir(folderPath); end
        end
        
    end

    methods (Static)
        function project = fromStruct(S)
            project = nansen.config.project.Project(S.Name, S.Path);
        end
    end
   
end