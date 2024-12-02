function varargout = backup(sessionObject, varargin)
%BACKUP Backup a session folder for the specified data location
%
%   BACKUP backs up data for the selected data location of a session.

% Todo:
%   [ ] Add mirror mode. (I.e delete files in target that are missing )
%   [ ] List all files in target
%   [ ] Delete files that are not present in list of files in source

import nansen.session.SessionMethod

% % % % % % % % % % % % CONFIGURATION CODE BLOCK % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify one or
% more attributes (see nansen.session.SessionMethod.setAttributes) for
% details. You can use the local function "getDefaultParameters" at the
% bottom of this file to define default parameters.

    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'queueable'};
    
    % Get all the data variable alternatives for this function. Add it to
    % the optional 'Alternatives' attribute to autogenerate a menu item for
    % each variable that can be opened as an imagestack object in imviewer.
    datalocationNames = getDataLocationAlternatives();
    ATTRIBUTES = [ATTRIBUTES, {'Alternatives', datalocationNames}];

% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % %
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - -
   
    % % % Initialization block for a session method function.

    if ~nargin && nargout > 0
        fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
        varargout = {fcnAttributes};   return
    end
    
    params.Alternative = datalocationNames{1}; % Set a default value.

    % % % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, true, varargin);
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
    
    dataLocationName = params.Alternative;

    backupDir = params.BackupLocation;
    
    if ~isfolder(backupDir)
        error('The specified backup location "%s" does not exist', params.BackupLocation)
    end

    fprintf('Backing up data (%s) for session "%s"\nto the location %s\n\n', ...
        dataLocationName, sessionObject.sessionID, backupDir)

    % List all files belonging to the session folder
    sessionFolder = sessionObject.getSessionFolder( dataLocationName );
    
    [subFolders, ~] = utility.path.listSubDir(sessionFolder, '', {}, inf);
    folders = cat(1, {sessionFolder}, subFolders');
    
    filepathList = utility.path.listFiles(folders);
    
    rootDirectorySource = sessionObject.getDataLocationRootDir( dataLocationName );
    
    filepathListRelative = strrep(filepathList, rootDirectorySource, '');
    
    % Loop through all files and copy or skip files depending on backup
    % mode
    numFiles = numel(filepathList);
    for i = 1:numFiles
    
        sourceFile = filepathList{i};
        targetFile = fullfile(backupDir, filepathListRelative{i});
        [targetFolder, filename] = fileparts(targetFile);
        
        % Default is to copy
        action = 'Copying';
        doCopyFile = true;

        switch params.BackupMode

            case 'merge (no replace)'
                if isfile(targetFile)
                    continue
                end

            case 'only replace files if newer'
                if isfile(targetFile)
                    L_Source = dir(sourceFile);
                    L_Target = dir(targetFile);
                    
                    if L_Source.datenum > L_Target.datenum
                        action = 'Replacing';
                    else
                        continue
                    end
                end

            case 'replace all files'
                if isfile(targetFile)
                    action = 'Replacing';
                end
            otherwise
                error('Not implemented')
        end
        
        fprintf('%s file %d/%d (%s)\n', action, i, numFiles, filename)
        if doCopyFile
            if ~isfolder(targetFolder); mkdir(targetFolder); end
            copyfile(  sourceFile, targetFolder )
        end
    end
    fprintf('Finished.')
end

function params = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    params = struct();
    
    params.BackupMode = 'merge (no replace)'; % Mode for backup. Options: "merge (no replace)", "only replace files if newer", "replace all files"
    params.BackupMode_ = {'merge (no replace)', 'only replace files if newer', 'replace all files'};
            
    params.BackupLocation = ''; % Absolute path to folder where data should be backed up
    params.BackupLocation_ = 'uigetdir';
end

function alternatives = getDataLocationAlternatives()
%getVariableNameAlternatives Collect a list of DataLocation names
    
    datalocationModel = nansen.DataLocationModel();
    alternatives = datalocationModel.DataLocationNames;
end
