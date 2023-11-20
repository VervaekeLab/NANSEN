classdef ProjectManager < handle
%nansen.config.project.ProjectManager Interface for managing projects
%
%   The purpose of this class is to simplify the process of listing
%   projects, adding new projects and changing the current project.
%
%   This is a singleton class, so any instance will always point to the
%   same object in memory.

%   Abbreviations:
%       PM - ProjectManager

% Todo:
%   [-] Implement as subclass of StorableCatalog, 
%   [+] or make a ProjectCatalog as a property of the projectmanager.
%   [ ] or make a HasCatalog superclass...
%   [ ] Have methods that are called from the UI class return messages,
%       and only call the fprintf on those messages whenever those methods
%       are called without outputs. something like (status, tf] = method()
%       This way the UI can catch info, warning, errors.
%   [ ] Move methods from projectmanager to project 
%   [ ] Add method for renaming project.
%   [ ] Add standard preferences
%   [x] Add option for saving as json
%   [ ] Add option for loading from json

    properties (Hidden) % Todo: Add to preferences.
        CatalogSaveFormat string {mustBeMember(CatalogSaveFormat, ["mat", "json"])} = "mat" % not implemented yet
    end

    properties (Hidden) % SetAccess = private
        Catalog             % A catalog of available projects
    end
    
    properties (Hidden, SetAccess = private)
        CatalogPath         % Path where catalog is saved
    end
        
    properties (Dependent, SetAccess = private)
        NumProjects
        ProjectNames
    end

    properties (SetAccess = private) 
        CurrentProject char
    end

    properties (Dependent)
        CurrentProjectPath
    end

    properties (Access = private)
        ProjectCache
    end

    events (NotifyAccess = private)
        CurrentProjectSet
    end

    events (ListenAccess = ?nansen.internal.user.NansenUserSession)
        CurrentProjectChanged
    end
    
    methods (Static, Hidden) %(Access = ?nansen.internal.user.NansenUserSession)

        function obj = instance(preferenceDirectory)
        %instance Get singleton instance of class

            if nargin < 1; preferenceDirectory = ''; end

            persistent instance

            if isempty(instance)
                instance = nansen.config.project.ProjectManager(preferenceDirectory);
            end
            
            obj = instance;
        end

    end
    
    methods (Access = private) % Constructor
       
        function obj = ProjectManager(preferenceDirectory)
            % Create instance of the project manager class
            obj.CatalogPath = obj.getCatalogPath(preferenceDirectory);
            obj.loadCatalog()

            obj.ProjectCache = containers.Map();
        end
        
    end
    
    methods (Static)
        
        function pStruct = getEmptyProjectStruct()
        %getEmptyProjectStruct Return a struct with fields for new project
            pStruct = struct('Name', {}, 'ShortName', {}, 'Description', {}, 'Path', {});
        end

    end
    
    methods % Set/get methods

        function numProjects = get.NumProjects(obj)
            numProjects = numel(obj.Catalog);
        end
        
        function pathStr = get.CurrentProjectPath(obj)
            project = obj.getCurrentProject();
            pathStr = project.FolderPath;
        end

        function projectNames = get.ProjectNames(obj)
            projectNames = string( {obj.Catalog.Name} );
        end
        
    end
    
    methods

        function pStruct = createProjectInfo(obj, name, description, pathStr)
        %createProjectInfo Create a struct with info for a project
            
            pStruct = obj.getEmptyProjectStruct();
            pStruct(1).Name = name; % Todo: This should be different from short name...
            pStruct(1).ShortName = name;
            pStruct(1).Description = description;
            pStruct(1).Path = pathStr;
        end
        
        function createProject(obj, name, description, projectRootDir, makeCurrentProject)
        %createProject Method for creating a new project entry
        
            if nargin < 5 || isempty(makeCurrentProject)
                makeCurrentProject = true; 
            end

            % Add project to project manager.
            projectInfo = obj.createProjectInfo(name, description, projectRootDir);
            
            nansen.config.project.Project.initializeProjectDirectory(projectInfo)
            
            obj.updateProjectConfiguration(projectRootDir, projectInfo)
            obj.updateModuleConfiguration(projectRootDir, projectInfo)

            % Create a project instance and initialize the project
            try
                newProject = nansen.config.project.Project(name, projectRootDir);
                newProject.initializeProject()
            catch MECause
                rmdir(projectRootDir, "s")
                ME = MException('Nansen:CreateProjectFailed', ...
                    'Failed to create project with name "%s"', name);
                ME = ME.addCause(MECause);
                throw(ME)
            end

            % Add project to project catalog if project was initialized
            obj.addProject(name, description, projectRootDir);

            % Set as current project
            if makeCurrentProject
                obj.changeProject(name)
            end
        end

        function projectName = importProject(obj, projectDirectory)
        %importProject Add an existing project to the PM catalog.
        %
        %   importProject(obj, filePath) import an existing project. The
        %   filePath should point to the project_configuration file located
        %   in the existing project folder.

            projectName = ''; %#ok<NASGU>

            try 
                S = nansen.config.project.Project.readConfigFile(projectDirectory);
                projectInfo = S.Properties;
            catch
                if isfile(fullfile(projectDirectory, 'nansen_project_configuration.mat'))
                    disp('Updating project...')
                    nansen.internal.refactor.reorganizeProjectFolder(projectDirectory, obj)
                    nansen.internal.refactor.updateVariableCatalog(projectDirectory)
                    return
                else
                    error('Expected folder to contain a "project.nansen.json file"')
                end
            end

            % Update filepath of project configuration to match the path
            % of the folder where the project file is located now
            projectInfo.Path = projectDirectory;
            obj.updateProjectConfiguration(projectDirectory, projectInfo)
                        
            obj.addProject(projectInfo)
            
            projectName = projectInfo.Name;
            if ~nargout; clear projectName; end
        end
        
        function updateProjectDirectory(obj, projectName, newProjectDirectory)
        %updateProjectDirectory Change the directory of an existing project.
        %
        %   Inputs:
        %       obj                 : The ProjectManager object that this method 
        %                             is a part of.
        %
        %       projectName         : A string that specifies the name of the 
        %                             project whose directory needs to be changed.
        %
        %       newProjectDirectory : A string that specifies the path to the 
        %                             new directory for the project.
        %
        %   Example usage: 
        %       updateProjectDirectory(obj, 'myProject', 'C:\Users\Documents\myNewProject');
        %
        %   Note: Use this method if the project directory has been moved already.
        %   If you want to move the project directory, use 'moveProject' instead

            % Update project folder in project catalog.
            IND = strcmp({obj.Catalog.Name}, projectName);
            obj.Catalog(IND).Path = newProjectDirectory;
             
            if isKey(obj.ProjectCache, projectName)
                % Update project folder in project instance.
                project = obj.ProjectCache(projectName);
                project.updateProjectFolder(newProjectDirectory);
            end
            
            obj.saveCatalog()
        end
        
        function moveProject(obj, projectName, newLocation)
        %moveProject Move the project to a new directory / file system location
        %
        %   Inputs:
        %       obj                 : The ProjectManager object that this method 
        %                             is a part of.
        %
        %       projectName         : A string that specifies the name of the 
        %                             project to move.
        %
        %       newProjectDirectory : A string that specifies the path where the
        %                             project should be moved to.
        
            project = obj.getProject(projectName);
            if isempty(project); return; end
            
            currentLocation = fileparts(project.Path);
            newPath = strrep(project.Path, currentLocation, newLocation);
            
            if contains(path, project.Path)
                rmpath(genpath(project.Path))
            end
            
            movefile(project.Path, newPath)
            
            IND = strcmp({obj.Catalog.Name}, projectName);
            obj.Catalog(IND).Path = newPath;

            if isKey(obj.ProjectCache, projectName)
                % Update project folder in project instance.
                project = obj.ProjectCache(projectName);
                project.updateProjectFolder(newProjectDirectory);
            end
            
            obj.saveCatalog()
        end
        
        function addProject(obj, varargin)
        %addProject Add project to the project catalog.
        %
        %   Input:
        %       obj      : An instance of this class.
        %
        %       varargin : A variable-length input argument list that can 
        %                  contain either a structure representing project 
        %                  information or a list of name-value pairs representing 
        %                  project information.
        %
        %   Example usage: 
        %       pm = nansen.ProjectManager(); 
        %       projectInfo = struct('Name', 'Project 1', 'Description', 'This is a test project', 'Path', 'C:\Users\Documents\myNewProject');
        %       pm.addProject(projectInfo);

        %   Todo : catalog method
        
            if numel(varargin) == 1 && isa(varargin{1}, 'struct')
                pStruct = varargin{1};
            elseif numel(varargin) > 2 && isa(varargin{1}, 'char')
                pStruct = obj.createProjectInfo(varargin{:});
            else
                error('Invalid input for addProject')
            end
            
            % Check that project with given name does not already exist
            isNameTaken = any(contains({obj.Catalog.Name}, pStruct.Name));
            if isNameTaken
                errMsg = 'Project with this name already exists.';
                error('Nansen:ProjectExists', errMsg)
            end
            
            nextInd = numel(obj.Catalog) + 1;
            
            % Add project info struct to catalog
            obj.Catalog(nextInd) = pStruct;
            
            obj.saveCatalog()
        end
       
        function removeProject(obj, name, deleteProjectFolder)
        %removeProject Remove project from project manager.
        %
        %   Inputs:
        %       obj                 : The ProjectManager object that this method 
        %                             is a part of.
        %
        %       projectName         : A string that specifies the name of the 
        %                             project whose directory needs to be changed.
        %
        %       deleteProjectFolder : (Optional) Logical flag for whether to 
        %                             delete the project directory from the file 
        %                             system (Default is false)
        %
        %   Example usage: 
        %       removeProject(obj, 'myProject');

            if nargin < 3
                deleteProjectFolder = false;
            end
            
            IND = strcmp({obj.Catalog.Name}, name);
            assert( sum(IND)>=1, 'Multiple projects were matched. Aborting...')
            
            % Todo: what if project is the current project? Abort!
            if strcmp(name, obj.CurrentProject)
                message = sprintf('Can not remove "%s" because it is the current project', name);
                errorID = 'NANSEN:Project:RemoveCurrentProjectDenied';
                throw(MException(errorID, message))
            end

            if any(IND)
                
                thisProject = obj.Catalog(IND);
                
                if deleteProjectFolder
                    folderPath = thisProject.Path;
                    if contains(path, folderPath)
                        rmpath(genpath(folderPath))
                    end
                    utility.system.deleteFolder(folderPath)
                    fprintf('Deleted project data for project "%s"\n', name)
                    
                    localDir = fileparts(obj.CatalogPath);
                    localProjectDir = fullfile(localDir, thisProject.Name);
                    
                    % Delete local project folder (when project
                    % folder) is saved externally
                    if ~isequal(localProjectDir, folderPath)
                        if isfolder(localProjectDir)
                            if contains(path, localProjectDir)
                                rmpath(genpath(localProjectDir))
                            end
                            utility.system.deleteFolder(localProjectDir)
                        end
                    end
                end
                
                obj.Catalog(IND) = [];
                
                msg = sprintf('Project "%s" removed from project catalog\n', name);
                fprintf(msg)
            end

            obj.saveCatalog()
        end
       
        function s = getProject(obj, name)
        %getProject Get project entry as struct given its name 

        % Todo: rename getProjectStruct or just remove and always return
        % object?
            IND = obj.getProjectIndex(name);
            
            if any(IND)
                s = obj.Catalog(IND);
            else
                s = struct.empty;
            end
        end

        function tf = containsProject(obj, projectName)
            tf = any(contains({obj.Catalog.Name}, projectName));
        end
        
        function projectObj = getProjectObject(obj, name)
        %getProjectObject Get project entry as object given its name
            
            if isKey(obj.ProjectCache, name)
                projectObj = obj.ProjectCache(name);
            else
                s = obj.getProject(name);
                if isempty(s)
                    projectObj = [];
                else
                    projectObj = nansen.config.project.Project(s.Name, s.Path);
                    obj.ProjectCache(name) = projectObj;
                end
            end
        end

        function projectObj = getCurrentProject(obj)
            projectObj = obj.getProjectObject(obj.CurrentProject);
        end
        
        function msg = changeProject(obj, nameOrIndex)
        %changeProject Change the current project
        %
        %   changeProject(obj, name) changes the current project to project
        %   with given name
                        
            import nansen.config.project.event.CurrentProjectChangedEventData
            
            if ~isempty(nameOrIndex)
                % Check that project with given name exists.
                projectEntry = obj.getProject(nameOrIndex);
                newProjectName = projectEntry.Name;
    
                if isempty(projectEntry)
                    errMsg = sprintf('Project with name "%s" does not exist', newProjectName);
                    error('Nansen:ProjectNonExistent', errMsg) %#ok<SPERR>
                end
            else
                newProjectName = '';
            end

            oldProjectName = obj.CurrentProject;

            if ~isempty(oldProjectName)
                prevProject = obj.getProjectObject(oldProjectName);
                obj.removeProjectFromSearchPath(prevProject.FolderPath)
            end

            obj.CurrentProject = newProjectName;
            if ~isempty(newProjectName)
                obj.addProjectToSearchPath( projectEntry.Path ) 
            end

            % Todo: remove
            global nansenPreferences
            
            % Reset local path variable
            if ~isempty(nansenPreferences)
                if isfield(nansenPreferences, 'localPath')
                    nansenPreferences.localPath = containers.Map;
                end
            end

            eventData = CurrentProjectChangedEventData(oldProjectName, newProjectName);
            obj.notify('CurrentProjectChanged', eventData)
            obj.notify('CurrentProjectSet', eventData)
            
            msg = sprintf('Current NANSEN project was changed to "%s"\n', newProjectName);
            if ~nargout
                fprintf(msg); clear msg
            end
        end
        
        function tf = uiSelectProject(obj, projectNames)
        %uiSelectProject Open selection dialog for selecting current projects    
            if nargin < 2
                projectNames = {obj.Catalog.Name};
            end
            
            promptStr = 'Select a project to open:';
            [ind, tf] = listdlg('ListString', projectNames, ...
                'PromptString', promptStr, 'Name', 'Select Project');
            
            if ~tf; return; end
            
            projectName = projectNames{ind};
            obj.changeProject(projectName);
        end
        
        function updateProjectItem(obj, projectName, name, value)
            IND = obj.getProjectIndex(projectName);
            if any(IND)
                obj.Catalog(IND).(name) = value;
                obj.saveCatalog()
            end
        end
    end

    methods % Load/save catalog

        function loadCatalog(obj)
        %loadCatalog Load the project catalog
            if ~exist(obj.CatalogPath, 'file')
                newCatalog = obj.getEmptyProjectStruct();
                S.projectCatalog = newCatalog;
            else
                S = load(obj.CatalogPath, 'projectCatalog');
            end
            
            obj.Catalog = S.projectCatalog;
        end
       
        function saveCatalog(obj)
        %saveCatalog Save the project catalog

            projectCatalog = obj.Catalog;  %#ok<NASGU

            if obj.CatalogSaveFormat == "mat"
                save(obj.CatalogPath, 'projectCatalog')
            elseif obj.CatalogSaveFormat == "json"
                jsonStr = jsonencode(projectCatalog, 'PrettyPrint', true);
                jsonPath = replace(obj.CatalogPath, '.mat', '.json');
                fid=fopen(jsonPath, 'w');
                fwrite(fid, jsonStr);
                fclose(fid);
            else

            end
        end

    end
    
    methods (Access = {?nansen.App, ?nansen.internal.user.NansenUserSession})

        function setProject(obj, newProjectName)
        %setProject Method for nansen app to initialize project and open
        % uiselection if current project is not available.
            
            import nansen.config.project.event.CurrentProjectChangedEventData

            oldProjectName = obj.CurrentProject;
            
            projectNames = {obj.Catalog.Name};
            
            if ~any(strcmp(newProjectName, projectNames))
                wasSuccess = obj.uiSelectProject(projectNames);
                if ~wasSuccess
                    error('Nansen:NoProjectSet', 'No project is set')
                else
                    return
                end
            else
                obj.CurrentProject = newProjectName;
                p = obj.getCurrentProject();
                obj.addProjectToSearchPath(p.FolderPath)

                if ~isempty(oldProjectName)
                    prevProject = obj.getProjectObject(oldProjectName);
                    obj.removeProjectFromSearchPath(prevProject.FolderPath)
                end
            end
                       
            % % Reset local path variable
            % global nansenPreferences
            % if ~isempty(nansenPreferences)
            %     if isfield(nansenPreferences, 'localPath')
            %         nansenPreferences.localPath = containers.Map;
            %     end
            % end

            eventData = CurrentProjectChangedEventData(oldProjectName, newProjectName);
            obj.notify('CurrentProjectSet', eventData)
        end
        
    end

    methods (Hidden)
    % Todo: Create a project class and put these methods there...
        
        function updateProjectConfiguration(obj, projectDirectory, projectInfo)
            % Todo: project method

            configFileName = nansen.config.project.Project.PROJECT_CONFIG_FILENAME;
            configFilePath = fullfile(projectDirectory, configFileName);
            
            S = utility.io.loadjson(configFilePath);

            S.Properties.Name = projectInfo.Name; % Todo: Should be a full name. Todo: Should be collected in app...
            S.Properties.ShortName = projectInfo.Name;
            S.Properties.Description = projectInfo.Description;

            utility.io.savejson(configFilePath, S)
        end

        function updateModuleConfiguration(~, projectDirectory, projectInfo)
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

        function S = listFigures(obj)
            
            S = struct('Name', '', 'FigureNames', '');
            
            figureDir = obj.getProjectSubPath('figures');
            
            % Find figure packages
            L = dir(fullfile(figureDir, '+*'));
           
            for i = 1:numel(L)
                
                S(i).Name = strrep( L(i).name, '+', '');
                L2 = dir(fullfile(L(i).folder, L(i).name, '+figure*'));
                
                figNames = strrep({L2.name}, '+', '');
                S(i).FigureNames = figNames;
            end
        end
        
    end

    methods (Access = private)
        
        function idx = getProjectIndex(obj, projectName)
        %getProjectIndex Get catalog index from name

            if isnumeric(projectName) % Assume index was given instead of name
                idx = projectName;
            else
                idx = find(strcmp({obj.Catalog.Name}, projectName));
            end
        end
        
    end

    methods (Sealed, Hidden) % Overridden display methods

        function display(obj, varName) %#ok<DISPLAY> 
            fprintf(newline)
            disp(obj)
            fprintf('  Use project = %s(rowNumber) to retrieve a Project from the catalog', varName)
            fprintf(newline)
            fprintf(newline)
            fprintf('See also %s\n', '<a href="matlab:methods nansen.config.project.ProjectManager" style="font-weight:bold">available methods</a>')
        end

        function disp(obj)
        %disp Override display function to show table of projects.

        % Inherit from matlab custom display?

            %titleTxt = sprintf(['<a href = "matlab: helpPopup %s">', ...
            %    'ProjectManager</a> with available projects:'],class(obj));
            
            builtin('disp', obj)
            
            if isempty(obj.Catalog)
                disp('NO AVAILABLE PROJECTS')
            else
                titleTxt = sprintf('  <strong>Available projects:</strong>');

                T = struct2table(obj.Catalog, 'AsArray', true);
                T.Properties.RowNames = arrayfun(@(i) num2str(i), 1:obj.NumProjects, 'uni', 0);
                T.Name = string(T.Name);
                fprintf('%s\n\n', titleTxt)
                disp(T)
                %fprintf('  The current project is <strong>%s</strong>\n\n', obj.CurrentProject)
            end
        end

    end

    methods (Sealed, Hidden) % Overridden indexing method

        function varargout = subsref(obj, s)
            
            numOutputs = nargout;
            varargout = cell(1, numOutputs);
                        
            if strcmp( s(1).type, '()')
                projectInfo = builtin('subsref', obj.Catalog, s(1));
                projectInstance = nansen.config.project.Project.fromStruct(projectInfo);
                if numel(s) == 1
                    [varargout{1}] = projectInstance;
                else
                    if numOutputs > 0
                        [varargout{:}] = builtin('subsref', projectInstance, s(2:end));
                    else
                        builtin('subsref', projectInstance, s(2:end))
                    end
                end
            else
                if numOutputs > 0
                    [varargout{:}] = builtin('subsref', obj, s);
                else
                    builtin('subsref', obj, s)
                end
            end
        end
        
        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            if strcmp( s(1).type, '()')
                projectInfo = builtin('subsref', obj.Catalog, s(1));
                projectInstance = nansen.config.project.Project.fromStruct(projectInfo);
                n = builtin('numArgumentsFromSubscript', projectInstance, s(2:end), indexingContext);
            else
                n = builtin('numArgumentsFromSubscript', obj, s, indexingContext);
            end
        end

    end

    methods (Static, Access = private)
        function addProjectToSearchPath(projectFolderPath)
            if ~contains(path, projectFolderPath)
                addpath(genpath(projectFolderPath), '-end')
            end
        end

        function removeProjectFromSearchPath(projectFolderPath)
            if contains(path, projectFolderPath)
                rmpath(genpath(projectFolderPath))
            end
        end
    end

    methods (Static, Hidden) % Todo: private?
        
        function pathStr = getCatalogPath(preferenceDirectory)

            if nargin < 1 || isempty(preferenceDirectory)
                preferenceDirectory = nansen.prefdir;
            end
                            
            projectRootPath = fullfile(preferenceDirectory, 'projects');
            
            % Get default project path
            if ~exist(projectRootPath, 'dir'); mkdir(projectRootPath); end
            
            % Add project details to project catalog file
            pathStr = fullfile(projectRootPath, 'project_catalog.mat');
        end
        
        function pathStr = getProjectPath(projectName, location)
            
            if ~nargin || strcmp(projectName, 'current')
                pm = nansen.ProjectManager;
                projectName = pm.CurrentProject;
            end
            
            pathStr = '';
            if isempty(projectName); return; end
            
            if nargin < 2; location = 'user'; end
            
            catalogPath = nansen.config.project.ProjectManager.getCatalogPath();
            S = load(catalogPath);

            isMatch = strcmp({S.projectCatalog.Name}, projectName);

            if strcmp(location, 'user') % user specific project data

                if any(isMatch)
                    pathStr = S.projectCatalog(isMatch).Path;
                else
                    pathStr = '';
                    warning('Project with name ''%s'' was not found', projectName);
                end
                
            elseif strcmp(location, 'local')
                
                % Local refers to local project configs, and it is stored
                % in the preference folder

                % Todo: get from nansen preferences
                localProjectPath = fullfile(nansen.prefdir, 'projects');
                
                pathStr = fullfile(localProjectPath, projectName);
                if ~exist(pathStr, 'dir'); mkdir(pathStr); end
                
            else
                
                error('Unknown location')
            end
        end
        
        function pathStr = getProjectCatalogPath(catalogName, subfolder)
        %getProjectCatalogPath Get path for catalog with given name
        %
        %   pathStr = getProjectCatalogPath(catalogName) creates a path for
        %   a catalog (storable catalog) under the current project. 
        %
        %   pathStr = getProjectCatalogPath(catalogName, subfolder)
        %   optionally specifies a subfolder within the project root
        %   directory where to store the catalog. Default subfolder is
        %   /Configurations.
        
            if nargin < 2
                subfolder = 'Configurations';
            end
            
            pm = nansen.ProjectManager;
            projectRootDir = pm.CurrentProjectPath;
            folderPath = fullfile(projectRootDir, subfolder);
            
            catalogName = utility.string.camel2snake(catalogName);
            fileName = strcat(catalogName, '.mat');
            
            % Make folder if it does not exist
            if ~exist(folderPath, 'dir');  mkdir(folderPath);    end
            
            pathStr = fullfile(folderPath, fileName);
        end
        
        % Todo: Deprecate: Should be part of project
        function pathStr = getProjectSubPath(keyword, projectRootDir)
        %getProjectSubPath Get a filepath within given current project
        %
        %   pathStr = getProjectSubPath(keyword) returns the pathStr for a
        %   file or folder belonging to the current project. Keyword is a
        %   descriptor for which file or folder to get the pathStr for. Use
        %   this function for standardizing the filepath for different
        %   files and folders belonging to a project.
        %  
        %   Supported keywords:
        %
        %       MetaTableCatalog
        %       MetaTable

            if nargin < 2
                pm = nansen.ProjectManager;
                projectRootDir = pm.CurrentProjectPath;
            end
            
            % Abort if project root directory is empty (non-existent)
            if isempty(projectRootDir)
                pathStr = '';
                return
            end
            
            % Determine path folder (and filename if relevant) based on
            % input keyword
            switch keyword
                case 'MetaTableCatalog'
                    saveDir = fullfile(projectRootDir, 'metadata', 'tables');
                    fileName = 'metatable_catalog.mat';
                case 'MetaTable'
                    saveDir = fullfile(projectRootDir, 'metadata', 'tables');
                case 'FilePathSettings'
                    saveDir = fullfile(projectRootDir, 'configurations');
                    fileName = 'filepath_settings.mat';
                case {'DataLocationSettings', 'DataLocationCatalog'}
                    saveDir = fullfile(projectRootDir, 'configurations');
                    fileName = 'datalocation_settings.mat';
                case 'PipelineAssignmentModel'
                    saveDir = fullfile(projectRootDir, 'configurations');
                    fileName = 'pipeline_settings.mat';  
                case {'figures', 'MultiPartFigures'}
                    saveDir = fullfile(projectRootDir, 'multipart_figures');
                otherwise
                    error('Unknown file label: %s', keyword)
            end
            
            % Make folder if it does not exist
            if ~exist(saveDir, 'dir');  mkdir(saveDir);    end
            
            % Prepare output, either file- or folderpath
            if exist('fileName', 'var')
                pathStr = fullfile(saveDir, fileName);
            else
                pathStr = saveDir;
            end
            
        end
      
        function pathStr = getFilePath(keyword)
            pathStr = nansen.config.project.ProjectManager.getProjectSubPath(keyword);
        end
    end
    

    methods (Access = ?nansen.internal.user.NansenUserSession)
        % Note: These methods will be removed in a future version (todo).
        
        function tf = hasUnversionedProjects(obj)
        % hasUnversionedProjects - Check if any projects are unversioned
            configFileName = nansen.common.constant.ProjectConfigFilename;

            TF = true(1, numel(obj.Catalog));

            for i = 1:numel(obj.Catalog)
                thisProjectDir = obj.Catalog(i).Path;
                TF(i) = ~isfile( fullfile(thisProjectDir, configFileName) );
            end
            tf = any(TF);
        end

        function upgradeProjects(obj)

            configFileName = nansen.common.constant.ProjectConfigFilename;

            if ~isfield(obj.Catalog, 'ShortName')
                [obj.Catalog(:).ShortName] = deal('');
            end

            for i = 1:numel(obj.Catalog)
                thisProjectDir = obj.Catalog(i).Path;
                if ~isfile( fullfile(thisProjectDir, configFileName) )
                    try
                        nansen.internal.refactor.reorganizeProjectFolder(thisProjectDir, obj)
                        nansen.internal.refactor.updateVariableCatalog(thisProjectDir)
                    end
                end
            end
        end

    end
end



% Change log
%
% 2023-03-05
% 
%   [x] Added documentation to public methods
%   [x] Improved object display
%   [x] Overrode subsref for better project retrieval 
%   [x] Implement as singleton
%   [x] Rename internal paths if an already existing project is added. 
%       Need to rename metatable etc...? Tested this. Was partly implemented 
%       from before. 
% 2023-09-18
%   [x] Create a project object cache in order to have singleton-like projects?
%
% 2023-11-20
%   [x] Remove the Preferences field from ProjectCatalog
%   [x] Add ShortName to ProjectCatalog
%   [x] Methods for "upgrading" a project to v1.0.0
%   [x] Improve methods for creating and importing projects
