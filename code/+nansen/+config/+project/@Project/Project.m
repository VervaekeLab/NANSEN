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
    %       list, and that also needs to be handled better. IncludedModules
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
        DataLocationModelSingleton
        VariableModelSingleton
    end

    properties (Constant, Hidden)
        % Todo: Folder property, with subfields?
        PROJECT_CONFIG_FILENAME = "project.nansen.json"
        METATABLE_FOLDER_NAME = fullfile('metadata', 'tables')
        CONFIG_FOLDER_NAME = 'configurations' % models
        METADATA_FOLDER_NAME = 'metadata'
    end

    properties (Constant, Access = private)
        % QTodo: Should this be retrieved from a constant or from module
        % manager/preferences?
        RequiredModuleName = nansen.common.constant.BaseModuleName;
    end
    
    % Constructor.
    methods (Access = {?nansen.config.project.ProjectManager, ?nansen.config.project.Project})
        function obj = Project(projectName, projectFolder)

            arguments
                projectName (1,1) string {nansen.config.project.mustBeValidProjectName}
                projectFolder (1,1) string {mustBeFolder}
            end

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
        function cd(obj)
            cd(obj.FolderPath)
        end

        function addToSearchPath(obj)
            obj.addProjectToSearchPath(obj.FolderPath) % delegate to static
        end

        function removeFromSearchPath(obj)
            obj.removeProjectFromSearchPath(obj.FolderPath) % delegate to static
        end
        
        function addMetaTable(obj, metaTable, metaTableType)
            arguments
                obj (1,1) nansen.config.project.Project
                metaTable (1,1) nansen.metadata.MetaTable
                % Todo: Add support for passing a standard MATLAB table,
                % and specifying a type manually using the metaTableType arg
                metaTableType (1,1) string = missing % Only relevant if we are adding a MATLAB table. 
            end
            if ~ismissing(metaTableType)
                warning('Passing a metatable type is not supported yet.')
            end

            MTC = obj.MetaTableCatalog();
            MTC.addMetatable(metaTable, true, true);
            MTC.save()
        end
        
        function mixinNames = listMixins(obj, itemType)
        %listFiles List files in a folder hierarchy for given item type
            
            % Todo: Module method should just look like this:
            fileList = obj.listFiles(itemType);
            filePaths = utility.dir.abspath(fileList);
            mixinNames = cellfun(@(c) utility.path.abspath2funcname(c), filePaths, 'uni', 0);
        end

        function folderList = getMixinFolders(obj, mixinType)
            folderList = obj.getMixinFolder(mixinType);
            for i = 1:numel(obj.IncludedModules)
                folderList(end+1) = obj.IncludedModules(i).getMixinFolder(mixinType); %#ok<AGROW>
            end
        end

        function folderPath = getConfigurationFolder(obj, options)
            arguments
                obj (1,1) nansen.config.project.Project
                % Subfolder : A list of subfolders
                options.Subfolder (1,:) string = string.empty
                options.NoCreate (1,1) logical = false
            end
            
            folderPath = fullfile(obj.FolderPath, obj.CONFIG_FOLDER_NAME);
            if ~isempty(options.Subfolder)
                folderPath = fullfile(folderPath, options.Subfolder{:});
                if ~isfolder(folderPath) && ~options.NoCreate
                    mkdir(folderPath)
                end
            end
        end

        function folderPath = getCustomOptionsFolder(obj)
            folderPath = obj.getConfigurationFolder('Subfolder', 'custom_options');
        end

        function folderPath = getMetadataFolder(obj, varargin)
            folderPath = fullfile(obj.FolderPath, obj.METADATA_FOLDER_NAME);
            folderPath = fullfile(folderPath, varargin{:});
        end

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
        
        function initializeProjectFolder(obj)
            % Todo: implement? I.e if a project object is created
            % programmatically
        end
        
        function folderPaths = getSessionMethodFolder(obj)
            folderPaths = obj.getObjectMethodFolder('Session');
        end

        function folderPaths = getObjectMethodFolder(obj, objectType, options)

            arguments
                obj (1,1) nansen.module.Module
                objectType (1,1) string
                options.IncludeModules (1,1) logical = true
            end

            if options.IncludeModules
                numModules = numel(obj.IncludedModules);
            else
                numModules = 0;
            end
            
            folderPaths = cell(1, numModules+1);

            folderPaths{1} = getObjectMethodFolder@nansen.module.Module(obj, objectType);
            for i = 1:numModules
                folderPaths{i+1} = obj.IncludedModules(i).getObjectMethodFolder(objectType);
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

            % Only keep unique files based on relative paths. Occurrence is
            % set to 'first', so that project files have highest priority,
            % then optional modules and last base modules.
            [~, IND] = unique(relFilePath, 'first');
            fileList = fileList(IND); % utility.dir.abspath(fileList);
        end
    end
    
    methods % TODO: implement a dataiomodel on project
        function saveData(obj, varName, data, options)
            arguments
                obj
                varName
                data
                options.SaveToJson (1,1) logical = false
            end

            filePathStr = obj.getDataFilePath(varName);
            
            if options.SaveToJson
                jsonStr = jsonencode(data, 'PrettyPrint', true);
                utility.filewrite(strcat(filePathStr, '.json'), jsonStr);
            else
                S.(varName) = data;
                save(filePathStr, '-struct', 'S');
            end
        end

        function data = loadData(obj, varName, options)
            arguments
                obj
                varName
                options.LoadFromJson (1,1) logical = false
            end
            
            filePathStr = obj.getDataFilePath(varName);
            if options.LoadFromJson
                try
                    data = jsondecode(fileread(strcat(filePathStr, '.json')));
                catch
                    data = obj.loadData(varName);
                end
            else
                S = load(filePathStr, varName);
                data = S.(varName);
            end
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
        
        function rename(obj, newName)
            
            oldName = obj.Name;
            oldModuleFolder = obj.getModuleFolder();

            % Change name property
            obj.Name = newName;
            obj.PackageName = strcat('+', obj.Name);
            
            % Update the project.nansen.json
            newProjectInfo = struct(...
                'Name', newName, 'Description', obj.Description);
            obj.updateProjectConfiguration(obj.FolderPath, newProjectInfo)

            % Update namespace folder name. Important to rename this before
            % renaming project folder
            newModuleFolder = obj.getModuleFolder();
            movefile(oldModuleFolder, newModuleFolder);

            % Change name of folder
            oldFolderpath = obj.FolderPath;
            newFolderpath = fullfile(fileparts(oldFolderpath), obj.Name);
            movefile(oldFolderpath, newFolderpath);
            obj.FolderPath = newFolderpath;

            % Rename FunctionNames in DataLocationModel
            obj.DataLocationModel.setFilePath(obj.getCatalogPath('DataLocationModel'));
            obj.DataLocationModel.onProjectRenamed(oldName, newName);

            obj.VariableModel.setFilePath(obj.getCatalogPath('VariableModel'));
            %obj.MetaTableCatalog.setFilePath(obj.getCatalogPath('MetaTableCatalog'))
            % todo
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
            if isempty(obj.DataLocationModelSingleton)
                obj.initializeDataLocationModel()
            end
            dataLocationModel = obj.DataLocationModelSingleton;
        end
        
        function variableModel = get.VariableModel(obj)
            if isempty(obj.VariableModelSingleton)
                obj.initializeVariableModel()
            end
            variableModel = obj.VariableModelSingleton;
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
            variableList = table2struct( obj.getTable('DataVariables') );

            % Call the method to initialize the variable list
            variableModel.addDataVariableSet(variableList)
        end
        
        function initializeModules(obj)
        % initializeModules - Initialize the included modules for a project
            
            % Note: Base module (required module) should be added last in
            % the list.

            if isfield(obj.Preferences, 'DataModule')
                
                moduleNames = obj.Preferences.DataModule;

                if isempty(moduleNames) || ~any(contains(moduleNames, obj.RequiredModuleName))
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
                    variableList = table2struct( module.getTable('DataVariables') );
                    obj.VariableModel.addDataVariableSet(variableList)
                end
            end
        end

        function initializeVariableModel(obj)
        % initializeVariableModel - Initialize a variable model
            filePath = obj.getCatalogPath('VariableModel');
            obj.VariableModelSingleton = nansen.config.varmodel.VariableModel(filePath);
        end
        
        function initializeDataLocationModel(obj)
        % initializeDataLocationModel - Initialize a dataloction model
            filePath = obj.getCatalogPath('DataLocationModel');
            obj.DataLocationModelSingleton = nansen.config.dloc.DataLocationModel(filePath);
        end

        function filePathStr = getCatalogPath(obj, catalogName)
        %getCatalogPath Get absolute path for catalog as character vector
        
            switch catalogName
                
                case 'MetaTableCatalog'
                    foldername = obj.METATABLE_FOLDER_NAME;
                    filename = 'metatable_catalog.mat';
                      
                % % Todo: Should this be here?
                % % case 'MetatableColumnSettingsCatalog'
                % %     foldername = obj.METATABLE_FOLDER_NAME;
                % %     filename = 'metatable_column_settings.mat';
                    
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
            if ~isfolder(folderPath); mkdir(folderPath); end
        end
    end
    
    methods (Static)
        function project = new(name, description, projectRootFolder)
            
            % Todo: Just add these as arguments to the project constructor...
            
            projectInfo = struct();
            projectInfo.Name = name; % Todo: This should be different from short name...
            projectInfo.ShortName = name;
            projectInfo.Description = description;
            projectInfo.Path = projectRootFolder;
            
            nansen.config.project.Project.initializeProjectDirectory(projectInfo)

            % Todo: Why is this here and not in the initialization function?
            nansen.config.project.Project.updateProjectConfiguration(projectRootFolder, projectInfo)
            nansen.config.project.Project.updateModuleConfiguration(projectRootFolder, projectInfo)

            % Create a project instance and initialize the project
            try
                project = nansen.config.project.Project(name, projectRootFolder);
                project.initializeProject()
            catch MECause
                rmdir(projectRootFolder, "s")
                ME = MException('Nansen:CreateProjectFailed', ...
                    'Failed to create project with name "%s"', name);
                ME = ME.addCause(MECause);
                throw(ME)
            end
        end
    end

    methods (Static, Access = {?nansen.config.project.Project, ?nansen.config.project.ProjectManager})
        function addProjectToSearchPath(projectFolderPath)
            if ~contains(path, projectFolderPath)
                addpath(genpath(projectFolderPath), '-end')
            end
            if isfile( fullfile(projectFolderPath, 'startup.m') )
                run(fullfile(projectFolderPath, 'startup.m'))
            end
        end

         function removeProjectFromSearchPath(projectFolderPath)
            if contains(path, projectFolderPath)
                rmpath(genpath(projectFolderPath))
            end
            if isfile(fullfile(projectFolderPath, 'finish.m'))
                run(fullfile(projectFolderPath, 'finish.m'))
            end
            % Todo: Remove dependent modules
        end
    end

    methods (Static, Hidden)
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
            % Check if project folder exists
            if ~isfolder(projectFolderPath)
                error('NANSEN:Project:ConfigurationFileMissing', ...
                    'No project folder was found with name: %s', projectFolderPath)
            end

            fileName = nansen.config.project.Project.PROJECT_CONFIG_FILENAME;
            filePath = fullfile(projectFolderPath, fileName);

            % Check if project configuration file exists
            if isfile(filePath)
                S = jsondecode(fileread(filePath));
            else
                error('NANSEN:Project:ConfigurationFileMissing', ...
                    'No project configuration file was found in folder: %s', projectFolderPath)
            end
        end

        function S = readOldConfigFile(projectFolderPath)
        % This can be removed in a future version
            filePath = fullfile(projectFolderPath, 'nansen_project_configuration.mat');
            if isfile(filePath)
                S = load(filePath, 'ProjectConfiguration');
            else
                error('NANSEN:Project:ConfigurationFileMissing', ...
                    'Project configuration file was not found')
            end
        end
    end
    
    % Methods related to initializing a project
    methods (Static, Access = {?nansen.config.project.ProjectManager, ?nansen.config.project.Project})

        function initializeProjectDirectory(projectInfo)
        % initializeProjectDirectory - Initialize a project  directory
            
            projectDirectoryPath = char( projectInfo.Path );
            projectName = char( projectInfo.Name );

            % Make folder for saving project related configs and metadata
            if ~isfolder(projectDirectoryPath)
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

        function updateProjectConfiguration(projectDirectory, projectInfo)
        % updateProjectConfiguration - Update project configuration file
            configFileName = nansen.config.project.Project.PROJECT_CONFIG_FILENAME;
            configFilePath = fullfile(projectDirectory, configFileName);
            
            S = utility.io.loadjson(configFilePath);

            S.Properties.Name = projectInfo.Name; % Todo: Should be a full name. Todo: Should be collected in app...
            S.Properties.ShortName = projectInfo.Name;
            S.Properties.Description = projectInfo.Description;

            utility.io.savejson(configFilePath, S)
        end

        function updateModuleConfiguration(projectDirectory, projectInfo)
            % Todo: module method?

            configFileName = nansen.module.Module.MODULE_CONFIG_FILENAME;
            L = utility.dir.recursiveDir(projectDirectory, 'Expression', configFileName);
            assert(numel(L)==1, 'Expected to found exactly one module configuration file, but found %s', numel(L))
            
            configFilePath = utility.dir.abspath(L);
            configFilePath = configFilePath{1};
            
            S = utility.io.loadjson(configFilePath);

            S.Properties.Name = projectInfo.Name;
            S.Properties.Description = projectInfo.Description;

            utility.io.savejson(configFilePath, S)
        end
    end
end
