function migrateUserdata(userSession)
%migrateUserdata Move the contents of _userdata to MATLAB's prefdir
%
%   The _userdata folder is a folder containing some important
%   configuration data, and it was originally part of the nansen repository
%   folder. This caused some problems when people reinstalled nansen
%   manually, and therefore the contents of this folder is now moved to
%   MATLAB's prefdir
    
    fprintf( ['The "_userdata" folder which was originally part of the NANSEN ' ...
           'repository \nfolder will now be moved to MATLAB''s preferences ' ...
            'directory.\n'])

    oldPath = fullfile(nansen.rootpath, '_userdata');
    newPath = userSession.getPrefdir();

    dateStr = char( datetime('now', 'Format', 'yyyyMMdd_hh_mm_ss') );
    backupPath = fullfile(userpath, 'Nansen', 'Backup', dateStr, '_userdata');
    if ~isfolder(backupPath); mkdir(backupPath); end
    
    try
        copyfile(oldPath, backupPath)
        copyfile(oldPath, newPath)
    catch ME
        newException = MException('NANSEN:UserDataMigrationFailed', ...
            'Could not copy userdata to new location. Please report!');
        newException = newException.addCause(ME);
        
        % Log the error message to the backup folder.
        errorFile = fullfile(backupPath, 'migration_failed_error.txt');
        utility.filewrite(errorFile, getReport(newException, 'extended'))
        throw(newException);
    end
    
    % If copy went fine, we can remove the original userdata folder from 
    % MATLAB's savepath and delete the folder from disk.
    rmpath(genpath(oldPath)); savepath
    disp('Removed _userdata from MATLAB''s search path and saved changes.')
    rmdir(oldPath, 's')
    fprintf('The "_userdata" folder was moved to %s\n', newPath)
end