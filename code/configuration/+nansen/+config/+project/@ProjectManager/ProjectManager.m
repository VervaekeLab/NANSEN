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
%   [x] Make a Project class.
%   [ ] Move methods from projectmanager to project 
%   [ ] Add method for renaming project.
%   [ ] Add standard preferences
%   [x] Add option for saving as json
%   [ ] Add option for loading from json
%   [ ] Create a project object cache in order to have singleton-like projects?

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

    properties (Dependent) 
        CurrentProject
        CurrentProjectPath
    end
    
    methods (Static, Hidden)

        function obj = instance()
        %instance Get singleton instance of class
            persistent instance

            if isempty(instance)
                instance = nansen.config.project.ProjectManager();
            end
            
            obj = instance;
        end

    end
    
    methods (Access = private) % Constructor
       
        function obj = ProjectManager()
            % Create instance of the project manager class
            obj.CatalogPath = obj.getCatalogPath();
            obj.loadCatalog()
        end
        
    end
    
    methods (Static)
        
        function pStruct = getEmptyProjectStruct()
        %getEmptyProjectStruct Return a struct with fields for new project
            pStruct = struct('Name', {}, 'Description', {}, 'Path', {});
        end

    end
    
    methods % Set/get methods
        
        function set.CurrentProject(obj, value)
            
        end
        
        function P = get.CurrentProject(~)
            P = getpref('Nansen', 'CurrentProject', []);
        end
        
        function numProjects = get.NumProjects(obj)
            numProjects = numel(obj.Catalog);
        end
        
        function pathStr = get.CurrentProjectPath(~)
            pathStr = getpref('Nansen', 'CurrentProjectPath', []);
        end

        function projectNames = get.ProjectNames(obj)
            projectNames = string( {obj.Catalog.Name} );
        end
        
    end
    
    methods

        function pStruct = createProjectInfo(obj, name, description, pathStr)
        %createProjectInfo Create a struct with info for a project
            
            pStruct = obj.getEmptyProjectStruct();
            pStruct(1).Name = name;
            pStruct(1).Description = description;
            pStruct(1).Path = pathStr;
        end
        
        function createProject(obj, name, description, projectRootDir)
        %createProject Method for creating a new project entry
        
            % Add project to project manager.
            projectInfo = obj.createProjectInfo(name, description, projectRootDir);
            obj.addProject(name, description, projectRootDir);

            % Make folder to save project related setting and metadata to
            if ~exist(projectRootDir, 'dir');    mkdir(projectRootDir);   end
            
            obj.saveProjectConfiguration(projectRootDir, projectInfo)

            % Todo:
            % (Initialize a metatable Catalog and add to project config)

            % Initialize a datalocation catalog (and add to project config)
            modelFilePath = obj.getProjectSubPath('DataLocationSettings', projectRootDir);
            nansen.config.initializeDataLocationModel(modelFilePath)
            
            % Initialize a variablemap Catalog (and add to project config)
            % Todo: Move this to a separate method. Should depend on user
            % selection of experimental modules. (Which will happen after
            % project is created.)
            modelFilePath = obj.getProjectSubPath('FilePathSettings', projectRootDir);
            nansen.config.initializeDataVariableModel(modelFilePath, 'ophys.twophoton')

            % Set as current project
            obj.changeProject(name)
        end
        
        function projectName = importProject(obj, filePath)
        %importProject Add an existing project to the PM catalog.
        %
        %   importProject(obj, filePath) import an existing project. The
        %   filePath should point to the project_configuration file located
        %   in the existing project folder.

            projectName = ''; %#ok<NASGU>
            projectDirectory = fileparts( filePath );

            S = load(filePath, 'ProjectConfiguration');
            projectInfo = S.ProjectConfiguration;
            
            % Update filepath of project configuration to match the path
            % of the folder where the project file is located now
            projectInfo.Path = projectDirectory;
            
            obj.saveProjectConfiguration(projectDirectory, projectInfo)

            % Update metatable catalog filepaths
            metaTableDir = fullfile(projectInfo.Path, 'Metadata Tables');
            MT = nansen.metadata.MetaTableCatalog(fullfile(metaTableDir, 'metatable_catalog.mat'));
            MT.updatePath( fullfile(projectInfo.Path, 'Metadata Tables') )
            MT.save()
            
            % Todo: Update datalocation filepaths (if they are not detected)...
            
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

            IND = strcmp({obj.Catalog.Name}, projectName);

            oldProjectDirectory = obj.Catalog(IND).Path;

            obj.Catalog(IND).Path = newProjectDirectory;
            
            obj.saveCatalog()

            % If project is current project, need to update prefs...
            if strcmp(obj.CurrentProject, projectName)
                setpref('Nansen', 'CurrentProjectPath', newProjectDirectory);
            end

            % Todo: Update project folder in project instance.

            % Update project folder in the metatable catalog
            obj.updateMetatableCatalogFilePaths(projectName, ...
                oldProjectDirectory, newProjectDirectory)
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
            
            obj.saveCatalog()

            obj.updateMetatableCatalogFilePaths(projectName, ...
                currentLocation, newLocation)
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
            isNameOccupied = any(contains({obj.Catalog.Name}, pStruct.Name));
            if isNameOccupied
                errMsg = 'Project with this name already exists.';
                error('Nansen:ProjectExists', errMsg)
            end
            
            nextInd = numel(obj.Catalog) + 1;

            % Add a preference struct if it does not exist
            if ~isfield(pStruct, 'Preferences')
                pStruct.Preferences = struct;
            end
            
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
            
            IND = obj.getProjectIndex(name);
            projectName = obj.Catalog(IND).Name;

            assert( sum(IND)>=1, 'Multiple projects were matched. Aborting...')
            
            % Todo: what if project is the current project? Abort!
            if strcmp(projectName, obj.CurrentProject)
                message = sprintf('Can not remove "%s" because it is the current project', projectName);
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
                    fprintf('Deleted project data for project "%s"\n', projectName)
                    
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
                
                msg = sprintf('Project "%s" removed from project catalog\n', projectName);
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
        
        function projectObj = getProjectObject(obj, name)
        %getProjectObject Get project entry as object given its name
            s = obj.getProject(name);
            projectObj = nansen.config.project.Project(s.Name, s.Path);
        end

        function projectObj = getCurrentProject(obj)
            currentProjectName = obj.CurrentProject;
            s = obj.getProject(currentProjectName);
            projectObj = nansen.config.project.Project(s.Name, s.Path);
        end
        
        function msg = changeProject(obj, name)
        %changeProject Change the current project
        %
        %   changeProject(obj, name) changes the current project to project
        %   with given name

            projectEntry = obj.getProject(name);
            projectName = projectEntry.Name;
            if isempty(projectEntry)
                errMsg = sprintf('Project with name "%s" does not exist', projectName);
                error('Nansen:ProjectNonExistent', errMsg) %#ok<SPERR>
            end
                        
            setpref('Nansen', 'CurrentProject', projectEntry.Name)
            setpref('Nansen', 'CurrentProjectPath', projectEntry.Path)
                        
            % Add project to path...
            if ~contains(path, projectEntry.Path)
                addpath(genpath(projectEntry.Path))
            end
            
            msg = sprintf('Current NANSEN project was changed to "%s"\n', projectName);
            if ~nargout
                fprintf(msg); clear msg
            end
            
            % Update data in nansenGlobal. Todo: Improve this...
            global nansenPreferences %dataLocationModel dataFilePathModel
            %if ~isempty(dataLocationModel); dataLocationModel.refresh(); end
            %if ~isempty(dataFilePathModel); dataFilePathModel.refresh(); end
            
            % Reset local path variable
            if ~isempty(nansenPreferences)
                if isfield(nansenPreferences, 'localPath')
                    nansenPreferences.localPath = containers.Map;
                end
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
            
            % Add preferences to each project entry if missing.
            if ~isfield( S.projectCatalog, 'Preferences' )
                % Todo: Fill out struct with default preference names?
                [S.projectCatalog(:).Preferences] = deal(struct);
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
       
    methods (Access = {?nansen.App})

        function setProject(obj)
        %setProject Method for nansen app to initialize project and open
        % uiselection if current project is not available.

            currentProject = obj.CurrentProject;
            
            projectNames = {obj.Catalog.Name};
            if ~any(strcmp(currentProject, projectNames))
                wasSuccess = obj.uiSelectProject(projectNames);
                if ~wasSuccess
                    error('Nansen:NoProjectSet', 'No project is set')
                end
            else
                projectPath = nansen.localpath('Current Project');
                %if ~contains(path, projectPath)
                    addpath(genpath(projectPath), '-end') % todo. dont brute force this..
                %end
            end
        end
        
    end

    methods (Hidden)
    % Todo: Create a project class and put these methods there...
        
        function saveProjectConfiguration(obj, projectDirectory, projectInfo)
            % Todo: project method
            fileName = 'nansen_project_configuration.mat';
            
            % Save project info to file.
            S.ProjectConfiguration = projectInfo;
            save(fullfile(projectDirectory, fileName), '-struct', 'S')
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
        
        function updateMetatableCatalogFilePaths(obj, projectName, oldDirectory, newDirectory)
        %updateMetatableCatalogFilePaths Update filepaths in the metatable
        % catalog

            % Todo: move this method to project class
            projectRootDir = obj.getProjectPath(projectName);
            pathStr = obj.getProjectSubPath('MetaTableCatalog', projectRootDir);

            % Todo: Make this a method of metatable catalog. 
            %  - Create or get project object
            %  - Call method on he project object's metatble catalog

            MTC = nansen.metadata.MetaTableCatalog.quickload(pathStr);

            for i = 1:size(MTC,1)
                MTC{i, 'SavePath'} = strrep(MTC{i, 'SavePath'}, oldDirectory, newDirectory);
                mtFilePath = fullfile( MTC{i, {'SavePath', 'FileName'}}{:} );
                MT = load( mtFilePath );
                MT.SavePath = MTC{i, 'SavePath'}{1};
                save(mtFilePath, '-struct', 'MT')
            end
            nansen.metadata.MetaTableCatalog.quicksave(MTC, pathStr)
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

    methods (Static, Hidden) % Todo: private?
        
        function pathStr = getCatalogPath()
            
            % Get default project path
            projectRootPath = fullfile(nansen.rootpath, '_userdata', 'projects');
            if ~exist(projectRootPath, 'dir'); mkdir(projectRootPath); end
            
            % Add project details to project catalog file
            pathStr = fullfile(projectRootPath, 'project_catalog.mat');
        end
        
        function pathStr = getProjectPath(projectName, location)
            
            if ~nargin || strcmp(projectName, 'current')
                projectName = getpref('Nansen', 'CurrentProject', '');
            end
            
            pathStr = '';
            if isempty(projectName); return; end
            
            if nargin < 2; location = 'user'; end
            
            catalogPath = nansen.config.project.ProjectManager.getCatalogPath();
            S = load(catalogPath);

            isMatch = strcmp({S.projectCatalog.Name}, projectName);
            
            
            if strcmp(location, 'user')

                if any(isMatch)
                    pathStr = S.projectCatalog(isMatch).Path;
                else
                    pathStr = '';
                    warning('Project with name ''%s'' was not found', projectName);
                end
                
            elseif strcmp(location, 'local')
                
                % Todo: get from nansen preferences
                localProjectPath = fullfile(nansen.rootpath, '_userdata', 'projects');
                
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
            
            projectRootDir = getpref('Nansen', 'CurrentProjectPath', '');
            folderPath = fullfile(projectRootDir, subfolder);
            
            catalogName = utility.string.camel2snake(catalogName);
            fileName = strcat(catalogName, '.mat');
            
            % Make folder if it does not exist
            if ~exist(folderPath, 'dir');  mkdir(folderPath);    end
            
            pathStr = fullfile(folderPath, fileName);
        end
        
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
            	projectRootDir = getpref('Nansen', 'CurrentProjectPath', '');
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
                    saveDir = fullfile(projectRootDir, 'Metadata Tables');
                    fileName = 'metatable_catalog.mat';
                case 'MetaTable'
                    saveDir = fullfile(projectRootDir, 'Metadata Tables');
                case 'FilePathSettings'
                    saveDir = fullfile(projectRootDir, 'Configurations');
                    fileName = 'filepath_settings.mat';
                case {'DataLocationSettings', 'DataLocationCatalog'}
                    saveDir = fullfile(projectRootDir, 'Configurations');
                    fileName = 'datalocation_settings.mat';
                case 'PipelineAssignmentModel'
                    saveDir = fullfile(projectRootDir, 'Configurations');
                    fileName = 'pipeline_settings.mat';  
                case {'figures', 'MultiPartFigures'}
                    saveDir = fullfile(projectRootDir, 'Multipart Figures');
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
