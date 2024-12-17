function pathStr = localpath(pathKeyword)
% Get (absolute) local paths for files & folders used in the nansen package
%
%   pathStr = localpath(pathKeyword)
%
%   This function provides absolute local paths for directory or filepaths
%   of folders or files that are used within the nansen package.

%   Use persistent variable to keep preference variables while matlab session
%   is running. Getting values using getprefs is quite slow, so this is a
%   "work around"

    arguments
        pathKeyword (1,1) string
    end
    
    persistent nansenLocalPathNames

    if isempty(nansenLocalPathNames)
        nansenLocalPathNames = struct('localPath', containers.Map);
    elseif ~isfield(nansenLocalPathNames, 'localPath')
        nansenLocalPathNames.localPath = containers.Map;
    end
    
    pathKeyword = char(pathKeyword);

    if isKey(nansenLocalPathNames.localPath, pathKeyword)
        pathStr = nansenLocalPathNames.localPath(pathKeyword);
        return
    end
    
    % Determine path folder (and filename if relevant) based input keyword
    switch pathKeyword
        
      % % Folders
        case 'session_method_templates'
            rootPath = fullfile(nansen.toolboxdir, '+nansen');
            folderPath = fullfile(rootPath, '+session', '+methods', '+template');
                
        case 'table_variable_templates'
            rootPath = fullfile(nansen.toolboxdir, '+nansen');
            folderPath = fullfile(rootPath, '+metadata', '+tablevar');
        
        case 'builtin_file_adapter'
            rootPath = fullfile(nansen.toolboxdir, '+nansen');
            folderPath = fullfile(rootPath, '+dataio', '+fileadapter');

        case {'_user_data', 'user_data', '_userdata', 'userdata'}
            folderPath = nansen.prefdir();
            
        case 'project_settings'
            folderPath = fullfile(nansen.prefdir, 'projects');
            
        case 'custom_options'
            folderPath = fullfile(nansen.prefdir, 'custom_options');
            
        case 'user_settings'
            folderPath = fullfile(nansen.prefdir, 'settings');
            
        case {'current_project_folder', 'Current Project'}
            pm = nansen.ProjectManager();
            folderPath = pm.CurrentProjectPath;
           
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
              
        otherwise
            % open dialog and save to preferences or get from preferences
            % if it exists there...
    
            % Check if preferences has a localpath field and if user defined local
            % paths are present there. Checking prefs is slow, so this is
            % the last resort (previously it was the first)
            
            if ispref('nansen_localpath', pathKeyword)
                pathStr = getpref('nansen_localpath', pathKeyword);
                nansenLocalPathNames.localPath(pathKeyword) = pathStr;
                return
            else
                error('No localpath found for "%s"', pathKeyword)
            end
    end
    
    % Make folder if it does not exist
    if ischar( folderPath )
        if ~isfolder(folderPath);  mkdir(folderPath);  end
    end
    
    % Prepare output, either file- or folderpath
    if exist('fileName', 'var')
        pathStr = fullfile(folderPath, fileName);
    else
        pathStr = folderPath;
    end
    
    nansenLocalPathNames.localPath(pathKeyword) = pathStr;
end
