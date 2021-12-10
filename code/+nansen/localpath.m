function pathStr = localpath(pathKeyword, project)
% Get (absolute) local paths for files & folders used in the nansen package
%
%   pathStr = localpath(pathKeyword)
%
%   See also nansen.config.addlocalpath (TODO)
%
%   This function provides absolute local paths for directory or filepaths
%   of folders or files that are used within the nansen package.
% 



%   Use global variable to keep preference variables while matlab session
%   is running. Getting values using getprefs is quite slow, so this is a
%   "work around"

    global nansenPreferences
    if isempty(nansenPreferences)
        nansenPreferences = struct('localPath', containers.Map);
    elseif ~isfield(nansenPreferences, 'localPath')
        nansenPreferences.localPath = containers.Map;
    end
    
    if isKey(nansenPreferences.localPath, pathKeyword)
        pathStr = nansenPreferences.localPath(pathKeyword);
        return
    end

    
    if nargin < 2 % Assume no project path is requested
        projectRootDir = '';
    elseif strcmp(project, 'current') % Should it be called current?
        projectRootDir = nansen.localpath('current_project_dir');
    else
        error('Project specification is not implemented yet')
    end

    % Determine path folder (and filename if relevant) based input keyword
    switch pathKeyword
        
      % % Folders
        
        case 'nansen_root'
            % Get folder for nansen root.
            thisPath = fileparts( mfilename( 'fullpath' ) );
            folderPath = utility.path.getAncestorDir(thisPath, 1);
            
        case 'subfolder_list'
            initPath = fullfile(nansen.localpath('nansen_root'), 'code');
            folderPath = strsplit(genpath(initPath), ':');
            folderPath = folderPath(1:end-1);

        case {'_user_data', 'user_data', '_userdata', 'userdata'} % Todo...
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata');
            
        case 'current_project_dir'
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
            folderPath = fullfile(projectRootDir, 'Metadata Tables', '+tablevar');
            
      % % Files
      
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
            
        case 'FilePathSettings'
            folderPath = fullfile(projectRootDir, 'Configurations');
            fileName = 'filepath_settings.mat';
            
        case 'DataLocationSettings'
            folderPath = fullfile(projectRootDir, 'Configurations');
            fileName = 'datalocation_settings.mat';
              
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

