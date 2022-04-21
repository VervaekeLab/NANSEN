classdef ProjectManager < handle
%nansen.config.project.ProjectManager Interface for managing projects
%
%   The purpose of this class is to simplify the process of listing
%   projects, adding new projects and changing the current project.

% Todo:
%   [ ] Implement as subclass of StorableCatalog, or make a ProjectCatalog
%       as a property of the projectmanager.
%   [ ] Have methods that are called from the UI class return messages,
%       and only call the fprintf on those messages whenever those methods
%       are called without outputs. something like (status, tf] = method()
%       This way the UI can catch info, warning, errors.
%   [ ] Make a Project class
%
%   [ ] IMPORTANT: Need to rename internal paths if an already existing
%       project is added. Need to rename metatable etc...?
%       % Only rootpath???
%   [ ] Add method for renaming project.


    properties
        Catalog             % A catalog of available projects
    end
    
    properties (SetAccess = private)
        CatalogPath         % Path where catalog is saved
    end
    
    properties (Dependent) 
        CurrentProject
        Projects
    end
    
    properties (Dependent, SetAccess = private)
        NumProjects
        CurrentProjectPath
    end
    
    
    methods
       
        function obj = ProjectManager()
            % Create instance of the project manager class
            obj.CatalogPath = obj.getCatalogPath();
            obj.loadCatalog()
        end
        
    end
    
    methods (Static)
        
        function pStruct = getEmptyProject()
            pStruct = struct('Name', {}, 'Description', {}, 'Path', {});
        end

    end
    
    methods % Set/get methods
        
        function set.CurrentProject(obj, value)
            
        end
        
        function P = get.CurrentProject(obj)
            P = getpref('Nansen', 'CurrentProject');
        end
        
        function numProjects = get.NumProjects(obj)
            numProjects = numel(obj.Catalog);
        end
        
        function pathStr = get.CurrentProjectPath(obj)
            pathStr = '';
        end
        
        function projects = get.Projects(obj)
            projects = obj.Catalog;
        end
        
    end
    
    methods
        
        function setProject(obj)
            
            currentProject = obj.CurrentProject();
            
            projectNames = {obj.Catalog.Name};
            if ~any(strcmp(currentProject, projectNames))
                wasSuccess = obj.uiSelectProject(projectNames);
                if ~wasSuccess
                    error('Nansen:NoProjectSet', 'No project is set')
                end
            else
                projectPath = nansen.localpath('Current Project');
                if ~contains(path, projectPath)
                    addpath(genpath(projectPath), '-end') % todo. dont brute force this..
                end
            end
        end
        
        function pStruct = createProjectInfo(obj, name, description, pathStr)
        %createProjectInfo Create a struct with info for a project
            
            pStruct = obj.getEmptyProject();
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
            
            fileName = 'nansen_project_configuration.mat';
            
            % Save project info to file.
            S.ProjectConfiguration = projectInfo;
            save(fullfile(projectRootDir, fileName), '-struct', 'S')

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
        
        function addExistingProject(obj, filePath)
            
            S = load(filePath, 'ProjectConfiguration');
            projectConfig = S.ProjectConfiguration;
            
            % Update filepath of project configuration to match the path
            % of the folder where the project file is located now
            projectConfig.Path = fileparts( filePath );
            
            % Update metatable catalog filepaths
            metaTableDir = fullfile(projectConfig.Path, 'Metadata Tables');
            MT = nansen.metadata.MetaTableCatalog(fullfile(metaTableDir, 'metatable_catalog.mat'));
            MT.updatePath( fullfile(projectConfig.Path, 'Metadata Tables') )
            MT.save()
            
            % Todo: Update datalocation filepaths (if they are not detected)...
            
            
            obj.addProject(projectConfig)
        end
        
        function disp(obj)
        %disp Override display function to show table of projects.
            titleTxt = sprintf(['<a href = "matlab: helpPopup %s">', ...
                'ProjectManager</a> with available projects:'],class(obj));
            if isempty(obj.Catalog)
                disp('NO AVAILABLE PROJECTS')
            else
                T = struct2table(obj.Catalog, 'AsArray', true);
                fprintf('%s\n\n', titleTxt)
                disp(T)
            end
        end
        
        function loadCatalog(obj)
        %loadCatalog Load the project catalog
            if ~exist(obj.CatalogPath, 'file')
                newCatalog = obj.getEmptyProject();
                S.projectCatalog = newCatalog;
            else
                S = load(obj.CatalogPath, 'projectCatalog');
            end
            
            obj.Catalog = S.projectCatalog;
        end
       
        function saveCatalog(obj)
        %saveCatalog Save the project catalog
            projectCatalog = obj.Catalog;  %#ok<NASGU
            save(obj.CatalogPath, 'projectCatalog')
        end
        
        function addProject(obj, varargin)
        %addProject Add project to the project catalog.
        
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
            
            % Add project info struct to catalog
            obj.Catalog(nextInd) = pStruct;
            
            obj.saveCatalog()
            
        end
       
        function removeProject(obj, name, deleteProjectFolder)
        %removeProject Remove project from project manager.
        
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
                end
                
                obj.Catalog(IND) = [];
                
                msg = sprintf('Project "%s" removed from project catalog\n', name);
                fprintf(msg)

            end

            obj.saveCatalog()
        end
       
        function s = getProject(obj, name)
        %getProject Get project entry given its name 
            IND = strcmp({obj.Catalog.Name}, name);
            
            if any(IND)
                s = obj.Catalog(IND);
            else
                s = struct.empty;
            end
            
        end
        
        function msg = changeProject(obj, name)
            
            projectEntry = obj.getProject(name);
            
            if isempty(projectEntry)
                errMsg = sprintf('Project with name "%s" does not exist', name);
                error('Nansen:ProjectNonExistent', errMsg) %#ok<SPERR>
            end
                        
            setpref('Nansen', 'CurrentProject', projectEntry.Name)
            setpref('Nansen', 'CurrentProjectPath', projectEntry.Path)
                        
            % Add project to path...
            if ~contains(path, projectEntry.Path)
                addpath(genpath(projectEntry.Path))
            end
            
            msg = sprintf('Current NANSEN project was changed to "%s"\n', name);
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
        
        function tf = uiselectProject(obj, projectNames)
            
            if nargin < 2
                projectNames = {obj.Catalog.Names};
            end
            
            [ind, tf] = listdlg('ListString', projectNames);
            
            if ~tf; return; end
            
            projectName = projectNames{ind};
            obj.changeProject(projectName);
            
        end
        
    end
   
    methods % Todo: Create a project class and put these methods there...
        
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
    
    methods (Static)
        
        function pathStr = getCatalogPath()
            
            % Get default project path
            nansenRoot = utility.path.getAncestorDir(nansen.rootpath, 1);
            projectRootPath = fullfile(nansenRoot, '_userdata', 'projects');
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
                    error('Project with name ''%s'' was not found', projectName);
                end
                
            elseif strcmp(location, 'local')
                
                nansenRoot = utility.path.getAncestorDir(nansen.rootpath, 1);
                localProjectPath = fullfile(nansenRoot, '_userdata', 'projects');
                
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