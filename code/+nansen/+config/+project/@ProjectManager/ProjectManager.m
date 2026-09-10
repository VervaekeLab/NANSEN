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
%   [+] or make a ProjectCatalog as a property of the projectmanager.
%   [ ] or make a HasCatalog superclass...
%   [ ] Move methods from projectmanager to project
%   [ ] Add method for renaming project.
%   [ ] Add standard preferences
%   [x] Add option for saving as json
%   [ ] Add option for loading from json

    properties (Hidden) % Todo: Add to preferences.
        CatalogSaveFormat string {mustBeMember(CatalogSaveFormat, ["mat", "json"])} = "mat" % not implemented yet
    end

    properties (Hidden) % SetAccess = private
        Catalog             % A catalog of available projects
    end

    properties (Hidden, SetAccess = private)
        CatalogDirectory    % Directory where the catalog and its project configurations are saved
        CatalogPath         % Path where catalog is saved
    end

    properties (Dependent, SetAccess = private)
        NumProjects
        ProjectNames
    end

    properties (SetAccess = private)
        CurrentProject char % Name of current project
    end

    properties (Dependent)
        CurrentProjectPath
    end

    properties (Access = private)
        ProjectCache % containers.Map
        PreferenceDirectory char % Directory holding this user's nansen preferences
    end

    properties (Constant, Access = private)
        CATALOG_FILENAME = "project_catalog.mat"

        % DEFAULT_FOLDER_NAME - Catalog folder within the preference directory
        DEFAULT_FOLDER_NAME = "projects"

        % LOCAL_FOLDER_NAME - Folder holding the per-machine subfolders
        LOCAL_FOLDER_NAME = "local"
    end

    events (NotifyAccess = private)
        CurrentProjectSet
    end

    events (ListenAccess = ?nansen.internal.user.NansenUserSession)
        % Todo: Document why this is needed in addition to
        % CurrentProjectSet event.
        CurrentProjectChanged
    end

    methods (Static, Hidden) %(Access = ?nansen.internal.user.NansenUserSession)

        function obj = instance(preferenceDirectory, mode)
        %instance Get singleton instance of class

            if nargin < 1; preferenceDirectory = ''; end
            if nargin < 2; mode = 'normal'; end

            persistent instance

            if isempty(instance) || strcmp(mode, 'reset')
                instance = nansen.config.project.ProjectManager(preferenceDirectory);
            end

            obj = instance;
        end
    end

    methods (Access = private) % Constructor

        function obj = ProjectManager(preferenceDirectory)
            % Create instance of the project manager class
            if nargin < 1 || isempty(preferenceDirectory)
                preferenceDirectory = nansen.prefdir();
            end

            obj.PreferenceDirectory = char(preferenceDirectory);
            obj.CatalogDirectory = obj.getCatalogDirectory(preferenceDirectory);
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

        function createProject(obj, name, description, projectRootDir, setAsCurrentProject)
        %createProject Method for creating a new project entry

            if nargin < 5 || isempty(setAsCurrentProject)
                setAsCurrentProject = true;
            end

            if ~isempty( obj.getProject(name) )
                error('Project with name "%s" already exists', name)
            end

            % Temporarily disable current project
            currentProject = obj.CurrentProject;
            if ~setAsCurrentProject
                setCurrentProjectCleanup = onCleanup(@() obj.changeProject(currentProject));
            end
            obj.changeProject('', "Verbose", false)

            % Add project to project manager.
            projectInfo = obj.createProjectInfo(name, description, projectRootDir);

            % Add check for whether project folder already exists
            projectDirectoryPath = char( projectInfo.Path );
            if isfolder(projectDirectoryPath)
                error('NANSEN:ProjectManager:ProjectFolderExists', ...
                    'Can not create project because a folder already exist in this location')
            end

            nansen.config.project.Project.initializeProjectDirectory(projectInfo)

            nansen.config.project.Project.updateProjectConfiguration(projectRootDir, projectInfo)
            nansen.config.project.Project.updateModuleConfiguration(projectRootDir, projectInfo)

            % Create a project instance and initialize the project
            try
                newProject = nansen.config.project.Project(name, projectRootDir);
                newProject.initializeProject()
            catch MECause
                rmdir(projectRootDir, "s")
                obj.changeProject(currentProject)
                ME = MException('Nansen:CreateProjectFailed', ...
                    'Failed to create project with name "%s"', name);
                ME = ME.addCause(MECause);
                throw(ME)
            end

            % Add project to project catalog if project was initialized
            obj.addProject(name, description, projectRootDir);

            % Set as current project
            if setAsCurrentProject
                obj.changeProject(name)
            end
        end

        function projectName = importProject(obj, projectDirectory)
        %importProject Add an existing project to the PM catalog.
        %
        %   importProject(obj, filePath) import an existing project. The
        %   filePath should point to the project_configuration file located
        %   in the existing project folder.

            arguments
                obj (1,1) nansen.config.project.ProjectManager
                projectDirectory (1,1) string = missing
            end

            projectName = '';

            if ismissing(projectDirectory)
                projectDirectory = uigetdir();
                if projectDirectory == 0
                    disp('User canceled')
                    return
                end
            end

            assert(isfolder(projectDirectory), 'Must provide path to an existing folder')

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
            nansen.config.project.Project.updateProjectConfiguration(projectDirectory, projectInfo)

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

        function renameProject(obj, projectName, newProjectName)
        %renameProject Rename a project

            arguments
                obj (1,1) nansen.config.project.ProjectManager
                projectName (1,1) string
                newProjectName (1,1) string
            end

            assert(...
                ~strcmp(projectName, newProjectName), ...
                'Project name must be different than current name')

            project = obj.getProjectObject(projectName);
            if isempty(project); return; end

            assert(... % Validate new name
                strcmp(newProjectName, matlab.lang.makeValidName(newProjectName)), ...
                 "New project name is not valid. Must consist of " + ...
                 "alphanumerics and underscores, and first character " + ...
                 "must be a letter.")

            % Unselect project if current, so that we don't rename folders
            % on MATLAB's search path
            currentProject = obj.CurrentProject;
            if strcmp(projectName, currentProject)
                obj.unselectProject(projectName)
            end

            project.rename(newProjectName)
            newPath = project.FolderPath;

            % Update name in project catalog
            IND = strcmp({obj.Catalog.Name}, projectName);
            obj.Catalog(IND).Name = newProjectName;
            obj.Catalog(IND).ShortName = newProjectName;
            obj.Catalog(IND).Path = newPath;

            obj.saveCatalog()

            % Select project if current
            if strcmp(projectName, currentProject)
                obj.changeProject(newProjectName)
            end
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
            newProjectDirectory = strrep(project.Path, currentLocation, newLocation);

            if contains(path, project.Path)
                rmpath(genpath(project.Path))
            end

            movefile(project.Path, newProjectDirectory)

            IND = strcmp({obj.Catalog.Name}, projectName);
            obj.Catalog(IND).Path = newProjectDirectory;

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

        function removeProject(obj, name, deleteProjectFolder, allowRemoveCurrentProject)
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

            arguments
                obj (1,1) nansen.config.project.ProjectManager
                name (1,1) string
                deleteProjectFolder (1,1) logical = false
                allowRemoveCurrentProject (1,1) logical = false
            end

            IND = obj.getProjectIndex(name);
            if numel(IND) == 0
                throwProjectNotFoundError(name)
            end
            assert( numel(IND)==1, 'Multiple projects were matched. Aborting...')

            projectName = obj.Catalog(IND).Name;

            % Check if project is current project and take appropriate
            % action
            if strcmp(projectName, obj.CurrentProject)
                if allowRemoveCurrentProject
                    obj.changeProject('')
                else
                    message = sprintf('Can not remove "%s" because it is the current project', projectName);
                    errorID = 'NANSEN:Project:RemoveCurrentProjectDenied';
                    throw(MException(errorID, message))
                end
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

                    % Delete the machine specific configurations for the
                    % project. These live in a separate folder, so they are
                    % not covered by deleting the project folder above.
                    localProjectDir = fullfile(obj.getLocalDirectory(), thisProject.Name);
                    if isfolder(localProjectDir)
                        if contains(path, localProjectDir)
                            rmpath(genpath(localProjectDir))
                        end
                        utility.system.deleteFolder(localProjectDir)
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

        function tf = containsProject(obj, projectName)
            tf = any(contains({obj.Catalog.Name}, projectName));
        end

        function projectObj = getProjectObject(obj, name)
        %getProjectObject Get project entry as object given its name
            if isempty(obj.ProjectCache)
                obj.ProjectCache = containers.Map;
            end
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

        function changeProject(obj, nameOrIndex, options)
        %changeProject Change the current project
        %
        %   changeProject(obj, name) changes the current project to project
        %   with given name

            arguments
                obj (1,1) nansen.config.project.ProjectManager
                nameOrIndex
                options.Verbose (1,1) logical = true
            end

            import nansen.config.project.event.CurrentProjectChangedEventData

            if ~isempty(nameOrIndex)
                % Check that project with given name exists.
                projectEntry = obj.getProject(nameOrIndex);

                if isempty(projectEntry)
                    errMsg = sprintf('Project with name "%s" does not exist', nameOrIndex);
                    error('Nansen:ProjectManager:ProjectDoesNotExist', errMsg) %#ok<SPERR>
                else
                    newProjectName = projectEntry.Name;
                end
            else
                newProjectName = '';
            end

            oldProjectName = obj.CurrentProject;

            if ~isempty(oldProjectName)
                obj.unselectProject(oldProjectName)
            end

            % Reset the cache to guard key collisions across projects.
            nansen.cache.DataCache.reset()

            obj.CurrentProject = newProjectName;
            if ~isempty(newProjectName)
                nansen.config.project.Project.addProjectToSearchPath(projectEntry.Path)
            end

            eventData = CurrentProjectChangedEventData(oldProjectName, newProjectName);
            obj.notify('CurrentProjectSet', eventData)
            obj.notify('CurrentProjectChanged', eventData)

            if options.Verbose
                fprintf('Current NANSEN project was changed to "%s"\n', newProjectName);
            end
        end

        function tf = uiSelectProject(obj, projectNames)
        %uiSelectProject Open selection dialog for selecting current projects
            if nargin < 2
                projectNames = {obj.Catalog.Name};
            end

            if isempty(projectNames); tf = false; return; end

            promptStr = 'Select a project to open:';
            [ind, tf] = listdlg('ListString', projectNames, ...
                'PromptString', promptStr, 'Name', 'Select Project');

            if ~tf; return; end

            projectName = projectNames{ind};
            obj.changeProject(projectName);
            if ~nargout
                clear tf
            end
        end

        function updateProjectItem(obj, projectName, name, value)
            IND = obj.getProjectIndex(projectName);
            if any(IND)
                obj.Catalog(IND).(name) = value;
                obj.saveCatalog()
            end
        end

        function reset(obj)
        %reset Delete every cached project object

            % Note: numel of a containers.Map is the number of map objects,
            % which is always one. Count the keys instead.
            projectNames = obj.ProjectCache.keys();

            for i = 1:numel(projectNames)
                delete( obj.ProjectCache(projectNames{i}) )
            end
            obj.ProjectCache = containers.Map;
        end

        function unselectProject(obj, projectName)
            % Todo: How is this different from changeProject
            try
                prevProject = obj.getProjectObject(projectName);
                prevProject.removeFromSearchPath()
            catch ME
                warning('Failed to clear project "%s". Reason:\n%s', projectName, ME.message)
            end
        end
    end

    methods % Load/save catalog

        function loadCatalog(obj)
        %loadCatalog Load the project catalog
            if ~isfile(obj.CatalogPath)
                newCatalog = obj.getEmptyProjectStruct();
                S.projectCatalog = newCatalog;
            else
                try
                    S = load(obj.CatalogPath, 'projectCatalog');
                catch ME
                    error('Nansen:ProjectManager:CatalogLoadError', ...
                        'Failed to load project catalog. Reason:\n%s', ME.message)
                end
            end

            % Ensure name and short name are char types.
            obj.Catalog = S.projectCatalog;
            for i = 1:numel(obj.Catalog)
                obj.Catalog(i).Name = char(obj.Catalog(i).Name);
                obj.Catalog(i).ShortName = char(obj.Catalog(i).ShortName);
            end
        end

        function saveCatalog(obj)
        %saveCatalog Save the project catalog

            projectCatalog = obj.Catalog;  %#ok<NASGU

            if obj.CatalogSaveFormat == "mat"
                save(obj.CatalogPath, 'projectCatalog')
            elseif obj.CatalogSaveFormat == "json"
                jsonStr = jsonencode(projectCatalog, 'PrettyPrint', true);
                jsonPath = nansen.util.path.changeFilenameExtension(obj.CatalogPath, 'json');
                fid = fopen(jsonPath, 'w');
                fwrite(fid, jsonStr);
                fclose(fid);
            else
            end
        end
    end

    methods % Catalog location

        function folderPath = getLocalDirectory(obj)
        %getLocalDirectory Get the directory for machine specific configurations
        %
        %   folderPath = getLocalDirectory(obj) returns the directory
        %   holding project configurations that belong to this machine
        %   only, such as local data root paths and task lists.
        %
        %   The catalog directory can be a shared or a synchronized folder,
        %   so these configurations are kept in a subfolder keyed by a
        %   machine identifier. Two machines sharing a catalog directory
        %   would otherwise overwrite each other's configurations.
        %
        %   See also nansen.config.project.ProjectManager/setCatalogDirectory

            import nansen.config.project.ProjectManager

            folderPath = char( fullfile(obj.CatalogDirectory, ...
                ProjectManager.LOCAL_FOLDER_NAME, ProjectManager.getMachineIdentifier()) );
        end

        function setCatalogDirectory(obj, newDirectory)
        %setCatalogDirectory Change where the project catalog is saved
        %
        %   setCatalogDirectory(obj, newDirectory) moves the project
        %   catalog, and the project configurations stored next to it, into
        %   newDirectory and remembers the location for later sessions.
        %
        %   setCatalogDirectory(obj, "") moves everything back to the
        %   default directory inside the user's preference directory.
        %
        %   MATLAB's preference directory belongs to a single MATLAB
        %   release, so the default location is not carried over when
        %   upgrading MATLAB. Point this at a release independent directory
        %   to keep the project catalog across upgrades.
        %
        %   The catalog is not moved if newDirectory already holds a
        %   project catalog, or any entry that the move would overwrite.
        %
        %   Example:
        %       pm = nansen.ProjectManager();
        %       pm.setCatalogDirectory("/Users/me/Documents/Nansen/projects")
        %
        %   See also nansen.config.project.ProjectManager/getLocalDirectory

            arguments
                obj (1,1) nansen.config.project.ProjectManager
                newDirectory (1,1) string
            end

            newDirectory = obj.resolveCatalogDirectory(newDirectory);
            oldDirectory = obj.CatalogDirectory;

            if obj.isSamePath(newDirectory, oldDirectory); return; end

            % Resolve everything that can fail before anything is moved.
            userSession = nansen.internal.user.NansenUserSession.instance('', 'nocreate');
            if isempty(userSession)
                error('NANSEN:ProjectManager:NoUserSession', ...
                    ['The project catalog location can only be changed while ' ...
                     'a NANSEN user session is active. Run "nansen.ProjectManager" ' ...
                     'to start a session, then change the location.'])
            end

            newCatalogPath = char( fullfile(newDirectory, obj.CATALOG_FILENAME) );
            if isfile(newCatalogPath)
                error('NANSEN:ProjectManager:CatalogExists', ...
                    ['A project catalog already exists in "%s". Select a ' ...
                     'directory without a project catalog, or remove the ' ...
                     'existing catalog first.'], newDirectory)
            end

            [sourcePaths, targetPaths] = obj.resolveMoveList(oldDirectory, newDirectory);

            % Cached project objects, and the current project's entries on
            % the search path, both point into the old directory. Restore
            % the current project on the way out, whether or not the move
            % succeeds.
            currentProjectName = obj.CurrentProject;
            if ~isempty(currentProjectName)
                obj.changeProject('', "Verbose", false)
                restoreCurrentProject = onCleanup( ...
                    @() obj.changeProject(currentProjectName, "Verbose", false) );
            end
            obj.reset()

            if ~isfolder(newDirectory); mkdir(newDirectory); end
            obj.moveEntries(sourcePaths, targetPaths, newDirectory)

            obj.CatalogDirectory = newDirectory;
            obj.CatalogPath = newCatalogPath;

            % An older installation can keep project folders inside the
            % catalog directory. Those projects have just been moved, so
            % their catalog entries no longer point at an existing folder.
            obj.updateProjectPathsAfterMove(oldDirectory, newDirectory)
            obj.saveCatalog()

            userSession.Preferences.ProjectCatalogDirectory = ...
                obj.toPreferenceValue(newDirectory);

            if isfolder(oldDirectory) && isempty( obj.listFolderContent(oldDirectory) )
                rmdir(oldDirectory)
            end

            fprintf('Project catalog directory was changed to "%s"\n', newDirectory)
        end
    end

    methods (Access = private) % Catalog location helpers

        function folderPath = resolveCatalogDirectory(obj, newDirectory)
        %resolveCatalogDirectory Validate a requested catalog directory

            if strlength(newDirectory) == 0
                folderPath = char( fullfile(obj.PreferenceDirectory, obj.DEFAULT_FOLDER_NAME) );
                return
            end

            folderPath = char(newDirectory);

            if ~obj.isAbsolutePath(folderPath)
                error('NANSEN:ProjectManager:RelativeCatalogDirectory', ...
                    ['"%s" is a relative path. Provide an absolute path, so ' ...
                     'that the project catalog is found independently of the ' ...
                     'current folder.'], folderPath)
            end

            parentDirectory = fileparts(folderPath);
            if ~isfolder(parentDirectory)
                error('NANSEN:ProjectManager:MissingParentDirectory', ...
                    ['The parent directory "%s" does not exist. Create it ' ...
                     'before moving the project catalog.'], parentDirectory)
            end
        end

        function [sourcePaths, targetPaths] = resolveMoveList(obj, sourceDirectory, targetDirectory)
        %resolveMoveList List the entries to move, and where they move to
        %
        %   movefile places sourceDirectory inside targetDirectory when the
        %   target already exists, so the entries are moved one by one.
        %   Every target is resolved up front, so a name collision can not
        %   leave the directory half moved.

            listing = obj.listFolderContent(sourceDirectory);

            sourcePaths = strings(1, numel(listing));
            targetPaths = strings(1, numel(listing));

            for i = 1:numel(listing)
                sourcePaths(i) = fullfile(sourceDirectory, listing(i).name);
                targetPaths(i) = fullfile(targetDirectory, listing(i).name);

                if isfolder(targetPaths(i)) || isfile(targetPaths(i))
                    error('NANSEN:ProjectManager:TargetExists', ...
                        ['"%s" already exists. Select a directory that does ' ...
                         'not contain an entry named "%s".'], ...
                        targetPaths(i), listing(i).name)
                end
            end
        end

        function moveEntries(~, sourcePaths, targetPaths, targetDirectory)
        %moveEntries Move the resolved entries, or move them all back
        %
        %   A move that stops halfway would leave the catalog split across
        %   two directories, where neither is a complete catalog directory.

            numMoved = 0;

            try
                for i = 1:numel(sourcePaths)
                    movefile(sourcePaths(i), targetPaths(i))
                    numMoved = i;
                end
            catch MECause
                for i = numMoved:-1:1
                    movefile(targetPaths(i), sourcePaths(i))
                end

                ME = MException('NANSEN:ProjectManager:MoveFailed', ...
                    ['Failed to move the project catalog to "%s", so it was ' ...
                     'left in its original location. Check that the directory ' ...
                     'is writable.'], targetDirectory);
                ME = ME.addCause(MECause);
                throw(ME)
            end
        end

        function updateProjectPathsAfterMove(obj, oldDirectory, newDirectory)
        %updateProjectPathsAfterMove Repoint catalog entries that moved along

            oldDirectory = obj.stripTrailingSeparator(oldDirectory);

            for i = 1:numel(obj.Catalog)
                projectPath = obj.Catalog(i).Path;
                if ~obj.isSubPath(projectPath, oldDirectory); continue; end

                relativePath = extractAfter(string(projectPath), strlength(oldDirectory));
                obj.Catalog(i).Path = char( fullfile(newDirectory, char(relativePath)) );
            end
        end

        function preferenceValue = toPreferenceValue(obj, folderPath)
        %toPreferenceValue Convert a directory to the value stored in preferences
        %
        %   The default directory is stored as an empty value, so that the
        %   catalog keeps following the preference directory of whichever
        %   user is active.

            defaultDirectory = fullfile(obj.PreferenceDirectory, obj.DEFAULT_FOLDER_NAME);

            if obj.isSamePath(folderPath, defaultDirectory)
                preferenceValue = "";
            else
                preferenceValue = string(folderPath);
            end
        end
    end

    methods (Static, Access = private) % Catalog location helpers

        function machineIdentifier = getMachineIdentifier()
        %getMachineIdentifier Get an identifier for the current machine
        %
        %   This is the same identifier the data location model uses as its
        %   SourceID, so that a project shared between machines resolves its
        %   local configurations and its local data root paths by one key.
        %
        %   The identifier is cached, because resolving it queries the
        %   operating system and it is needed on every local path lookup.

            persistent cachedIdentifier

            if isempty(cachedIdentifier)
                cachedIdentifier = string( utility.system.getComputerName(true) );
            end
            machineIdentifier = cachedIdentifier;
        end

        function listing = listFolderContent(folderPath)
        %listFolderContent List the entries of a folder, without "." and ".."
            listing = dir(folderPath);
            listing = listing( ~ismember({listing.name}, {'.', '..'}) );
        end

        function tf = isAbsolutePath(pathStr)
        %isAbsolutePath Check whether a path is absolute on this platform
            pathStr = char(pathStr);
            if ispc
                tf = ~isempty( regexp(pathStr, '^([A-Za-z]:[\\/]|\\\\)', 'once') );
            else
                tf = startsWith(pathStr, '/');
            end
        end

        function tf = isSamePath(pathA, pathB)
        %isSamePath Compare two paths, ignoring a trailing file separator
            import nansen.config.project.ProjectManager

            pathA = ProjectManager.stripTrailingSeparator(pathA);
            pathB = ProjectManager.stripTrailingSeparator(pathB);

            if ispc
                tf = strcmpi(pathA, pathB);
            else
                tf = strcmp(pathA, pathB);
            end
        end

        function tf = isSubPath(pathStr, parentPath)
        %isSubPath Check whether a path is located inside a parent directory
            import nansen.config.project.ProjectManager

            parentPath = ProjectManager.stripTrailingSeparator(parentPath);
            tf = startsWith(string(pathStr), strcat(parentPath, filesep), "IgnoreCase", ispc);
        end

        function pathStr = stripTrailingSeparator(pathStr)
        %stripTrailingSeparator Remove trailing file separators from a path
            pathStr = char(pathStr);
            while numel(pathStr) > 1 && strcmp(pathStr(end), filesep)
                pathStr(end) = [];
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
                nansen.config.project.Project.addProjectToSearchPath(p.FolderPath)

                if ~isempty(oldProjectName)
                    obj.unselectProject(oldProjectName)
                end
            end

            eventData = CurrentProjectChangedEventData(oldProjectName, newProjectName);
            obj.notify('CurrentProjectSet', eventData)
        end
    end

    methods (Hidden)
    % Todo: Create a project class and put these methods there...

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
                assert(idx >= 1 && idx <= obj.NumProjects, ...
                    'NANSEN:ProjectManager:IndexOutOfBounds', ...
                    'Index out of bounds. Must be between 1 and %d', obj.NumProjects)
            elseif ischar(projectName) || isstring(projectName)
                idx = find(strcmp({obj.Catalog.Name}, projectName));
            else
                error('Project name must be a string or char array')
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

    methods (Static, Hidden) % Todo: private?

        function pathStr = getCatalogPath(preferenceDirectory)
        %getCatalogPath Get the file path of the project catalog
        %
        %   pathStr = getCatalogPath() returns the path for the current
        %   user session.
        %
        %   pathStr = getCatalogPath(preferenceDirectory) returns the path
        %   for the user whose preferences are stored in
        %   preferenceDirectory.
        %
        %   See also nansen.config.project.ProjectManager/getCatalogDirectory

            import nansen.config.project.ProjectManager

            if nargin < 1; preferenceDirectory = ''; end

            projectRootPath = ProjectManager.getCatalogDirectory(preferenceDirectory);

            % Get default project path
            if ~isfolder(projectRootPath); mkdir(projectRootPath); end

            % Add project details to project catalog file
            pathStr = char( fullfile(projectRootPath, ProjectManager.CATALOG_FILENAME) );
        end

        function folderPath = getCatalogDirectory(preferenceDirectory)
        %getCatalogDirectory Get the directory where the project catalog is saved
        %
        %   folderPath = getCatalogDirectory() returns the directory for
        %   the current user session.
        %
        %   folderPath = getCatalogDirectory(preferenceDirectory) returns
        %   the directory for the user whose preferences are stored in
        %   preferenceDirectory.
        %
        %   The directory is the ProjectCatalogDirectory preference when
        %   one is set, and a "projects" folder inside the preference
        %   directory otherwise.
        %
        %   Note: The preference is read from file rather than from the
        %   user session, because this method runs while the user session
        %   is still constructing its project manager.
        %
        %   See also nansen.internal.user.Preferences/readValue

            import nansen.config.project.ProjectManager

            if nargin < 1 || isempty(preferenceDirectory)
                preferenceDirectory = nansen.prefdir();
            end

            folderPath = nansen.internal.user.Preferences.readValue(...
                preferenceDirectory, "ProjectCatalogDirectory");

            if strlength(folderPath) == 0
                folderPath = fullfile(preferenceDirectory, ProjectManager.DEFAULT_FOLDER_NAME);
            end
            folderPath = char(folderPath);
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

                % Local refers to project configs that belong to this
                % machine only, and are kept out of the shareable part of
                % the catalog directory.

                pm = nansen.config.project.ProjectManager.instance();

                pathStr = fullfile(pm.getLocalDirectory(), projectName);
                if ~isfolder(pathStr); mkdir(pathStr); end

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
            if ~isfolder(folderPath);  mkdir(folderPath);    end

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
            if ~isfolder(saveDir);  mkdir(saveDir);    end

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

        function migrateLocalProjectFolders(obj)
        %migrateLocalProjectFolders Move local configurations into the machine folder
        %
        %   Machine specific project configurations used to sit directly in
        %   the catalog directory, one folder per project. They now live in
        %   a subfolder keyed by machine identifier, so that a catalog
        %   directory can be shared between machines without them
        %   overwriting each other's configurations.
        %
        %   See also nansen.config.project.ProjectManager/getLocalDirectory

            if isempty(obj.Catalog); return; end

            localDirectory = obj.getLocalDirectory();

            legacyFolderPaths = string.empty;
            targetFolderPaths = string.empty;

            for i = 1:numel(obj.Catalog)
                projectName = obj.Catalog(i).Name;
                legacyFolderPath = fullfile(obj.CatalogDirectory, projectName);

                if ~isfolder(legacyFolderPath); continue; end

                % An older installation can keep the project folder itself
                % here. That folder is project data, not a configuration.
                if obj.isSamePath(legacyFolderPath, obj.Catalog(i).Path); continue; end

                targetFolderPath = fullfile(localDirectory, projectName);
                if isfolder(targetFolderPath)
                    warning('NANSEN:ProjectManager:LocalConfigurationConflict', ...
                        ['Local configurations for project "%s" exist both in ' ...
                         '"%s" and in "%s". The configurations in "%s" were ' ...
                         'left untouched.'], projectName, obj.CatalogDirectory, ...
                        localDirectory, obj.CatalogDirectory)
                    continue
                end

                legacyFolderPaths(end+1) = legacyFolderPath; %#ok<AGROW>
                targetFolderPaths(end+1) = targetFolderPath; %#ok<AGROW>
            end

            if isempty(legacyFolderPaths); return; end

            if ~isfolder(localDirectory); mkdir(localDirectory); end
            for i = 1:numel(legacyFolderPaths)
                movefile(legacyFolderPaths(i), targetFolderPaths(i))
            end

            fprintf('Machine specific project configurations were moved to "%s"\n', ...
                localDirectory)
        end

        function checkProjectsExist(obj)
        % checkProjectsExist - Check if project folders exists.
            missingProjectNames = string.empty;
            missingProjectPaths = string.empty;

            for i = 1:numel(obj.Catalog)
                thisProjectDir = obj.Catalog(i).Path;
                if ~isfolder(thisProjectDir)
                    thisProjectName = obj.Catalog(i).Name;
                    missingProjectNames(end+1) = obj.Catalog(i).Name; %#ok<AGROW>
                    missingProjectPaths(end+1) = obj.Catalog(i).Path; %#ok<AGROW>
                    %showProjectMissingWarning(thisProjectName, thisProjectDir)
                end
            end
            if ~isempty(missingProjectNames)
                showProjectMissingWarning2(missingProjectNames, missingProjectPaths)
            end
        end

        function tf = hasUnversionedProjects(obj)
        % hasUnversionedProjects - Check if any projects are unversioned
            configFileName = nansen.common.constant.ProjectConfigFilename;

            TF = true(1, numel(obj.Catalog));

            for i = 1:numel(obj.Catalog)
                thisProjectDir = obj.Catalog(i).Path;
                if isfolder(thisProjectDir)
                    TF(i) = ~isfile( fullfile(thisProjectDir, configFileName) );
                else
                    TF(i) = false; % Folder missing, no project to check
                end
            end
            tf = any(TF);
        end

        function upgradeProjects(obj)

            configFileName = nansen.common.constant.ProjectConfigFilename;

            if ~isfield(obj.Catalog, 'ShortName')
                [obj.Catalog(:).ShortName] = deal('');
            end

            msg = sprintf( ...
                "\nProject folders will be updated to work with the latest code changes. " + ...
                "If any project folder is on a cloud location it is important " + ...
                "that you make sure all files are downloaded before continuing.\n");
            title = "Updating Project Folders...";
            formattedMessage = strcat('\fontsize{16}', msg);
            opts = struct('WindowStyle', 'modal', 'Interpreter', 'tex');

            uiwait( msgbox(formattedMessage, title, 'help', opts) )

            msg = sprintf( ...
                "\nI confirm that all my project files are available on the local file system.\n");
            title = "Updating Project Folders...";
            formattedMessage = strcat('\fontsize{16}', msg);
            opts = struct('WindowStyle', 'modal', 'Interpreter', 'tex', 'Default', 'Confirm');
            answer = questdlg(formattedMessage, title, 'Confirm', 'Cancel', opts);
            if ~strcmp(answer, 'Confirm')
                error('Operation canceled')
            end

            % Run in reverse, as functions below will remove project from
            % catalog and then re-add it...
            for i = numel(obj.Catalog):-1:1
                thisProjectDir = obj.Catalog(i).Path;
                if ~isfile( fullfile(thisProjectDir, configFileName) )
                    try
                        nansen.internal.refactor.reorganizeProjectFolder(thisProjectDir, obj)
                        nansen.internal.refactor.updateVariableCatalog(thisProjectDir)
                    catch ME
                        disp(getReport(ME, 'extended'))
                    end
                end
            end

            % Todo: Reorder catalog to original order?
        end
    end
end

function throwProjectNotFoundError(projectName)
    error('NANSEN:ProjectManager:ProjectNotFound', ...
        'Project with name "%s" does not exist.', projectName)
end

function showProjectMissingWarning(projectName, projectFolder)
    nansen.common.tracelesswarning(...
        'NANSEN:ProjectManager:ProjectMissing', ...
        ['Project "%s" was not found at expected location:\n%s\nRun ', ...
        'nansen.ProjectManager to remove the project or update it''s location.\n'], ...
        projectName, projectFolder)
end

function showProjectMissingWarning2(projectNames, projectFolders)

    projectList = compose("  %s -> %s", projectNames', projectFolders');
    projectList = strjoin(projectList, newline);

    if numel(projectNames) == 1
        warningMessage = sprintf(...
            ['The following project was not found:\n%s\nRun ', ...
            'nansen.ProjectManager to remove the project or update it''s ', ...
            'location.\n'], projectList);
    else
        warningMessage = sprintf(...
            ['The following projects were not found:\n%s\nRun ', ...
            'nansen.ProjectManager to remove the projects or update their ', ...
            'locations.\n'], projectList);
    end

    nansen.common.tracelesswarning(...
        'NANSEN:ProjectManager:ProjectMissing', warningMessage)
end

% Change log
%
% 2023-03-05
%
%   [x] Added documentation to public methods
%   [x] Improved object display
%   [x] Overrode subsref for better project retrieval
%   [x] Implement as singleton
%   [x] Rename internal paths if an already existing project is added.
%       Need to rename metatable etc...? Tested this. Was partly implemented
%       from before.
% 2023-09-18
%   [x] Create a project object cache in order to have singleton-like projects?
%
% 2023-11-20
%   [x] Remove the Preferences field from ProjectCatalog
%   [x] Add ShortName to ProjectCatalog
%   [x] Methods for "upgrading" a project to v1.0.0
%   [x] Improve methods for creating and importing projects
