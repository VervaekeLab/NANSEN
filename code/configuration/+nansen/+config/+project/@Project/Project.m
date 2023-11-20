classdef Project < nansen.module.Module
%Project A class to represent a Project

    % Work in progress.
    
    % This object should reflect the content of a project folder and have
    % methods for interacting with data in the project folder.
    
    % Todo : 
    %   [ ] Clean up object display
    %   [ ] Define preferences explicitly somehow.
    %   [ ] Should there be a project preference whether to save task lists
    %       for a project?
    %   [ ] implement onPreferencesChanged callback function...
    %   [ ] Create method for getting data variables.
    %   [ ] Better system for distinguishing between optional and required
    %       modules. Also, the required module should come last (?) in the
    %       list, and that also eneds to be handled better. IndludedModules
    %       could be dependent, and there could be additional properties to
    %       store optional and base/required modules.
    
    properties % Inherited from module
        %Name                        % Name of the project
    end

    properties (SetAccess = private)
        IncludedModules nansen.module.Module
    end
    
    properties (SetAccess = private)
        FolderPath char             % Path to the project folder
    end
    
    properties (Dependent, SetAccess = private)
        Preferences                 % Preferences for the project
    end

    properties (Dependent)
        MetaTableCatalog            % Catalog of metadata tables
        MetaTableViewCatalog        % Catalog of metadata table views
        DataLocationModel           % Data location model for the project
        VariableModel               % Variable model for the project
    end

    properties (Access = private)
        PackageName                 % Name of matlab package folder for the project
    end
    
    properties (Access = private)
        MetaTableCatalog_   % internal store if catalog is already loaded. However, this would not be up to date it the catalog is changed. Think it is better that this is just a dependent property... 
    end

    properties (Constant, Hidden)
        % Todo: Folder property, with subfields?
        PROJECT_CONFIG_FILENAME = "project.nansen.json"
        METATABLE_FOLDER_NAME = fullfile('metadata', 'tables');
        CONFIG_FOLDER_NAME = 'configurations'; % models
    end

    properties (Constant, Access = private)
        % QTodo: Should this be retreived from a constant or from module 
        % manager/preferences? 
        RequiredModuleName = nansen.common.constant.BaseModuleName;
    end
    
    methods (Access = ?nansen.config.project.ProjectManager)
        function obj = Project(projectName, projectFolder)
            
            configFileName = nansen.module.Module.MODULE_CONFIG_FILENAME;
            packageName = strcat('+', projectName); % Todo: Short name

            obj@nansen.module.Module(fullfile(projectFolder, 'code', packageName, configFileName));
            
            obj.Name = projectName; % Todo: Full Name
            obj.PackageName = packageName; % Todo: Short name
            
            obj.FolderPath = projectFolder;
            obj.initializeModules()
        end
    end
    
    methods
        function folderPath = getModuleFolder(obj)
            folderPath = fullfile(obj.FolderPath, 'code', obj.PackageName);
        end

        function addModules(obj)

        end

        function removeModules(obj)

        end

        function setOptionalModules(obj, optionalModulesNames)
        % setOptionalModules - Set optional modules for project.

            % Update the DataModule in preferences. Note: The required
            % module is added last in this list.
            newModuleNames = [optionalModulesNames, {obj.RequiredModuleName}];
            obj.Preferences.DataModule = newModuleNames;
            obj.updateModules()
        end

        % Todo: remove
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
        
        function folderPaths = getSessionMethodFolder(obj)
            
            folderPaths = cell(1, numel(obj.IncludedModules));

            folderPaths{1} = getSessionMethodFolder@nansen.module.Module(obj);
            for i = 1:numel(obj.IncludedModules)
                folderPaths{i+1} = obj.IncludedModules(i).getSessionMethodFolder();
            end
            folderPaths = cellfun(@(c) char(c), folderPaths, 'uni', 0);
        end
    end

    methods (Access = protected) % Override module methods

        function fileList = listFiles(obj, itemType)
        %listFiles List files in a folder hierarchy for given item type

            [fileList, relFilePath] = listFiles@nansen.module.Module(obj, itemType);
            
            for i = 1:numel(obj.IncludedModules)
                [fileList_, relFilePath_] = obj.IncludedModules(i).listFiles(itemType);
                fileList = cat(1, fileList, fileList_);
                relFilePath = cat(1, relFilePath, relFilePath_);
            end

            % Only keep unique files based on relative paths. Occurence is
            % set to 'first', so that project files have highest priority,
            % then optional modules and last base modules.
            [~, IND] = unique(relFilePath, 'first');
            fileList = fileList(IND); % utility.dir.abspath(fileList);
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

        function folderPath = getProjectPackagePath(obj, packageName)
            % Note, this should be a module method...
            
            try
                folderPath = obj.getProjectFolderPathStatic(obj.FolderPath, packageName);
            catch
                error('No package with name %s is defined.', packageName)
            end
        end
    end

    methods (Access = ?nansen.config.project.ProjectManager)
        
        function renameProject(obj, newName)
            
            oldName = obj.Name;

            % Change name property
            obj.Name = newName;
            obj.PackageName = strcat('+', obj.Name);
            
            % Change name of folder
            oldFolderpath = obj.FolderPath;
            newFolderpath = fullfile(fileparts(oldFolderpath), obj.Name);
            movefile(oldFolderpath, newFolderpath);
            obj.FolderPath = newFolderpath;

            % Rename FunctionNames in DataLocationModel
            obj.DataLocationModel.onProjectRenamed(oldName, newName);

        end

        function updateProjectFolder(obj, newFolderPath)
            obj.FolderPath = newFolderPath;
        end

        function initializeProject(obj)
            obj.initializeConfigurations()
            obj.initializeProjectReadme()
            obj.Preferences.DataModule = {};
        end
    
    end
    
    methods % Set/get

        function preferences = get.Preferences(obj)
            filePath = fullfile(obj.FolderPath, obj.PROJECT_CONFIG_FILENAME);
            
            S = utility.io.loadjson(filePath);
            if isfield(S, 'Preferences')
                preferences = S.Preferences;
            else
                preferences = struct;
            end

            if isfield(preferences, 'DataModule')
                if iscolumn(preferences.DataModule) % ensure row
                    preferences.DataModule = preferences.DataModule';
                end
            end
        end
        function set.Preferences(obj, preferences)
            %Todo: update data modules if those are changed
            filePath = fullfile(obj.FolderPath, obj.PROJECT_CONFIG_FILENAME);
            S = utility.io.loadjson(filePath);
            S.Preferences = preferences;
            utility.io.savejson(filePath, S);
        end
        
        function metatableCatalog = get.MetaTableCatalog(obj)
            filePath = obj.getCatalogPath('MetaTableCatalog');
            metatableCatalog = nansen.metadata.MetaTableCatalog(filePath);
        end
                
        function metatableCatalog = get.MetaTableViewCatalog(obj)
            % Todo: What is this?
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
        
        function initializeProjectReadme(obj)
        % initializeProjectReadme - Initialize project's readme file   
            readmeFilePath = fullfile(obj.FolderPath, 'README.md');

            fileStr = fileread(readmeFilePath);
            fileStr = strrep(fileStr, "{{project.name}}", obj.Name);
            fileStr = strrep(fileStr, "{{project.description}}", obj.Description);
            utility.filewrite(readmeFilePath, fileStr)
        end

        function initializeConfigurations(obj)
            
            % Initialize a datalocation catalog         
            modelFilePath = obj.getCatalogPath('DataLocationModel');
            nansen.config.initializeDataLocationModel(modelFilePath)
            
            % Initialize the variable model.
            modelFilePath = obj.getCatalogPath('VariableModel');
            variableModel = nansen.config.varmodel.VariableModel(modelFilePath);
            
            % Get variable list from included modules
            variableList = table2struct( obj.getTable('DataVariable') );

            % Call the method to initialize the variable list
            variableModel.addDataVariableSet(variableList)
        end
        
        function initializeModules(obj)
        % initializeModules - Initialize the included modules for a project
            
            % Note: Base module (required module) should be added last in
            % the list.

            if isfield(obj.Preferences, 'DataModule')
                
                moduleNames = obj.Preferences.DataModule;

                if isempty(moduleNames) || ~contains(moduleNames, obj.RequiredModuleName)
                    moduleNames = [moduleNames, {obj.RequiredModuleName}];
                    obj.Preferences.DataModule = moduleNames;
                end
               
                moduleNames = unique(moduleNames, 'stable'); % Just in case...
                
                for i = 1:numel(moduleNames)                
                    module = nansen.module.Module.fromName(moduleNames{i});
                    obj.IncludedModules(i) = module;
                end
            end
        end

        function updateModules(obj)
        %updateModules Assign modules based on preferences
        %
        % Note: The base module should always be added last in this list.
        % When finding unique files, the prioritized order for selecting
        % files is: project, optional modules, base module.
            
            currentModules = obj.IncludedModules;
            currentModuleIDs = [currentModules.ID];
            
            if isfield(obj.Preferences, 'DataModule')

                baseModule = obj.RequiredModuleName; % QTodo: remove this?
                newModuleIDs = [obj.Preferences.DataModule, {baseModule}];
                newModuleIDs = unique(newModuleIDs, 'stable'); % Just in case...
    
                addedModuleID = setdiff(newModuleIDs, currentModuleIDs, 'stable');
                [~, removeIdx] = setdiff(currentModuleIDs, newModuleIDs);

                % Remove any modules that were included but not any more
                for i = numel(removeIdx):-1:1
                    % removedModule = obj.IncludedModules(removeIdx(i));
                    obj.IncludedModules(removeIdx(i)) = [];
                    
                    % Remove variables (Not needed?): 
                    %variableList = removedModule.DataVariables;
                    %obj.VariableModel.removeDataVariableSet(variableList)
                end

                % Add any modules that are included but was not before.
                for i = 1:numel(addedModuleID)
                    module = nansen.module.Module.fromName(addedModuleID{i});
                    obj.IncludedModules = [module, obj.IncludedModules];
                    
                    % Update variable model based on module's template variables
                    variableList = table2struct( module.getTable('DataVariable') );
                    obj.VariableModel.addDataVariableSet(variableList)
                end
            end
        end

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
        % getLocalProjectFolderPath - Get folder for local project configs

        % Note: Projects contains userdata that can be stored on cloud.
        % Some configurations are needed to be local, so there is a
        % separate folder to store platform dependent configs.

        % Todo: Rename to getProjectPreferenceDirectory()

            localProjectPath = fullfile(nansen.prefdir, 'projects');
            
            folderPath = fullfile(localProjectPath, obj.Name);
            if ~exist(folderPath, 'dir'); mkdir(folderPath); end
        end
        
    end

    methods (Static)
        function project = fromStruct(S)
            project = nansen.config.project.Project(S.Name, S.Path);
        end

        function filePath = getProjectFilePathStatic(projectFolderPath, fileKey)
            import nansen.config.project.Project

            switch fileKey
                case 'Metatable Catalog'
                    filePath = Project.getProjectFolderPathStatic(projectFolderPath, 'Metadata Tables');

            end
            
        end

        function folderPath = getProjectFolderPathStatic(projectDirectory, folderKey)
        % getProjectFolderPathStatic - Get path to subfolder within project directory
            
            import nansen.config.project.Project
            
            [~, projectName] = fileparts(projectDirectory);
            moduleDirectory = fullfile(projectDirectory, 'code', ['+', projectName]);
            
            switch folderKey
                case 'Session Methods'
                    folderPath = fullfile(moduleDirectory, '+sessionmethod');
                case 'Table Variables'
                    folderPath = fullfile(moduleDirectory, '+tablevariable');
                case 'File Adapters'
                    folderPath = fullfile(moduleDirectory, '+fileadapter');
                case 'Metadata Tables'
                    folderPath = fullfile(projectDirectory, Project.METATABLE_FOLDER_NAME);
                otherwise
                    error('No folder with name %s is defined for projects.', folderKey)
            end
        end
    
        function S = readConfigFile(projectFolderPath)
            fileName = nansen.config.project.Project.PROJECT_CONFIG_FILENAME;
            filePath = fullfile(projectFolderPath, fileName);

            if isfile(filePath)
                S = jsondecode(fileread(filePath));
            else
                error('Nansen:ProjectConfigurationFileMissing', ...
                    'No project configuration file was found in folder: %s', projectFolderPath)
            end
        end

        function S = readOldConfigFile(projectFolderPath)
        % This can be removed in a future version
            filePath = fullfile(projectFolderPath, 'nansen_project_configuration.mat');
            if isfile(filePath)
                S = load(filePath, 'ProjectConfiguration');
            else
                error('Project configuration file was not found')
            end
        end
    end
    
    % Methods related to initializing a project
    methods (Static, Access = ?nansen.config.project.ProjectManager)

        function initializeProjectDirectory(projectInfo)
        % initializeProjectDirectory - Initialize a project  directory    
            
            projectDirectoryPath = projectInfo.Path;
            projectName = projectInfo.Name;

            % Make folder for saving project related configs and metadata
            if ~exist(projectDirectoryPath, 'dir')  
                mkdir(projectDirectoryPath);   
            end

            % Copy project template to new folder
            rootFolder = utility.path.getAncestorDir( mfilename('fullpath'), 2 );
            projectTemplateDirectory = fullfile(rootFolder, 'resources', 'project_folder_template');
            copyfile(projectTemplateDirectory, projectDirectoryPath)

            % Copy module template folder to the code folder
            moduleTemplateDirectory = nansen.module.Module.getModuleTemplateDirectory();
            targetDirectory = fullfile(projectDirectoryPath, 'code', ['+', projectName]);
            copyfile(moduleTemplateDirectory, targetDirectory);
            rmdir(fullfile(targetDirectory, 'resources'), "s")
        end
        
    end
end