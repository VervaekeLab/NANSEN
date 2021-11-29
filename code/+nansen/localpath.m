function pathStr = localpath(pathKeyword, project)
% Get (absolute) local paths for files & folders used in the nansen package
%
%   pathStr = localpath(pathKeyword)
%
%   See also nansen.config.addlocalpath (TODO)

    
    if ispref('nansen_localpath', pathKeyword)
        pathStr = getpref('nansen_localpath', pathKeyword);
        return
    end



    if nargin < 2 || strcmp(project, 'current') % Should it be called current?
        projectRootDir = getpref('Nansen', 'CurrentProjectPath'); %todo: add default
    else
        error('Not implemented yet')
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
            
        case 'project_settings'
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata', 'projects');
            
        case 'custom_options'
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata', 'custom_options');
            
        case 'user_settings'
            initPath = nansen.localpath('nansen_root');
            folderPath = fullfile(initPath, '_userdata', 'settings');
            
        case 'current_project_folder'
            folderPath = getpref('Nansen', 'CurrentProjectPath');
            
        case {'MetaTable', 'metatable_folder'}
            folderPath = fullfile(projectRootDir, 'Metadata Tables');
            
            
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
            
            error('No localpath found for "%s"', pathKeyword)
            
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
            
    
end