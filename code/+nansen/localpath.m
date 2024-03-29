function pathStr = localpath(pathKeyword, projectName)
% Get (absolute) local paths for files & folders used in the nansen package
%
%   pathStr = localpath(pathKeyword)
%
%   See also nansen.config.addlocalpath (TODO)
%
%   This function provides absolute local paths for directory or filepaths
%   of folders or files that are used within the nansen package.

% Todo: Should not give project dependent paths. This is a task for
% ProjectManager, or better, a Project class.

%   Use global variable to keep preference variables while matlab session
%   is running. Getting values using getprefs is quite slow, so this is a
%   "work around"

    global nansenPreferences
    if isempty(nansenPreferences)
        nansenPreferences = struct('localPath', containers.Map);
    elseif ~isfield(nansenPreferences, 'localPath')
        nansenPreferences.localPath = containers.Map;
    end
    
    if nargin < 2 || isempty(projectName) || strcmp(projectName, 'current')
        if isKey(nansenPreferences.localPath, pathKeyword)
            pathStr = nansenPreferences.localPath(pathKeyword);
            return
        end
    end

    
    if nargin < 2 || isempty(projectName) || strcmp(projectName, 'current')% Should it be called current?
        projectRootDir = nansen.config.project.ProjectManager.getProjectPath();
    else
        projectRootDir = nansen.config.project.ProjectManager.getProjectPath(projectName);
    end

    % Determine path folder (and filename if relevant) based input keyword
    switch pathKeyword
        
      % % Folders
        
        case {'nansen_root', 'root'}
            % Get folder for nansen root.
            folderPath = nansen.rootpath();

        case 'integrations'
            rootPath = fullfile(nansen.localpath('root'));
            folderPath = fullfile(rootPath, 'code', 'integrations');
            
        case 'sessionmethods'
            rootPath = fullfile(nansen.localpath('integrations'));
            folderPath = fullfile(rootPath, 'sessionmethods');

        case 'session_method_templates'
            rootPath = fullfile(nansen.rootpath, 'code', '+nansen');
            folderPath = fullfile(rootPath, '+session', '+methods', '+template');
                
        case 'table_variable_templates'
            rootPath = fullfile(nansen.rootpath, 'code', '+nansen');
            folderPath = fullfile(rootPath, '+metadata', '+tablevar');
        
        case 'builtin_file_adapter'
            rootPath = fullfile(nansen.rootpath, 'code', '+nansen');
            folderPath = fullfile(rootPath, '+dataio', '+fileadapter');

        case 'subfolder_list'
            initPath = fullfile(nansen.localpath('nansen_root'), 'code');
            folderPath = strsplit(genpath(initPath), pathsep);
            folderPath = folderPath(1:end-1);

        case {'_user_data', 'user_data', '_userdata', 'userdata'} % Todo...
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata');
            
        case {'current_project_dir', 'project'}
            rootDir = fullfile(nansen.localpath('user_data'));
            defaultProjectDir = fullfile(rootDir, 'projects', 'default');
            folderPath = getpref('Nansen', 'CurrentProjectPath', defaultProjectDir); %todo: add default
            
        case 'project_settings'
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata', 'projects');
            
        case 'custom_options'
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata', 'custom_options');
            
        case 'user_settings'
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata', 'settings');
            
        case {'current_project_folder', 'Current Project'}
            folderPath = getpref('Nansen', 'CurrentProjectPath');
            
        case {'MetaTable', 'metatable_folder'}
            folderPath = fullfile(projectRootDir, 'Metadata Tables');
            
        case 'Custom Metatable Variable'
            [~, projectName] = fileparts(projectRootDir);

            folderPath = fullfile(projectRootDir, 'Metadata Tables', ...
                ['+', projectName], '+tablevar');
            
        case 'Data Variable Template Folder'
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, 'templates', 'datavariables');
            
      % % Files
      
        case 'WatchFolderCatalog'
            folderPath = nansen.localpath('user_settings');
            fileName = 'watch_folder_catalog.mat';
            
        case 'TaskList'
            folderPath = nansen.localpath('user_settings');
            fileName = 'task_list.mat';
            
        case 'ProjectCatalog'
            initPath = nansen.localpath('user_data');
            folderPath = fullfile(initPath, 'projects');
            fileName = 'project_catalog.mat';

        case 'MetaTableCatalog'
            folderPath = fullfile(projectRootDir, 'Metadata Tables');
            fileName = 'metatable_catalog.mat';
            
        case 'ProjectConfiguration'
            folderPath = fullfile(projectRootDir, 'Configurations');
        
        case {'ProjectCustomOptions', 'project_custom_options'}
            folderPath = fullfile(projectRootDir, 'Configurations', 'custom_options');
            
        case 'FilePathSettings'
            folderPath = fullfile(projectRootDir, 'Configurations');
            fileName = 'filepath_settings.mat';
            
        case 'DataLocationSettings'
            folderPath = fullfile(projectRootDir, 'Configurations');
            fileName = 'datalocation_settings.mat';
            
        case 'SessionMatchMaker'
            [~, projectName] = fileparts(projectRootDir);
            folderPath = fullfile(projectRootDir, ['+', projectName]);
            fileName = 'matchFolderListWithSessionID.m';
              
        otherwise
            % open dialog and save to preferences or get from preferences
            % if it exists there...
    
            % Check if preferences has a localpath field and if user defined local
            % paths are present there. Checking prefs is slow, so this is
            % the last resort (previously it was the first)
            
            if ispref('nansen_localpath', pathKeyword)
                pathStr = getpref('nansen_localpath', pathKeyword);
                nansenPreferences.localPath(pathKeyword) = pathStr;
                return
            else
                error('No localpath found for "%s"', pathKeyword)
            end
            
    end
    
    
    % Make folder if it does not exist
    if ischar( folderPath )
        if ~exist(folderPath, 'dir');  mkdir(folderPath);  end
    end
    
    % Prepare output, either file- or folderpath
    if exist('fileName', 'var')
        pathStr = fullfile(folderPath, fileName);
    else
        pathStr = folderPath;
    end
    
    nansenPreferences.localPath(pathKeyword) = pathStr;

end

