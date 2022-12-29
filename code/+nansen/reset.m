function reset()
%Reset Reset all settings of this software package. 


    %% Ask user to confirm.
    msg = sprintf(['\nThis will reset all settings for this package, and ', ...
        'the operation can not be undone. \nAre you sure you want to continue? ', ...
        'Enter y or n: ']);
    answer = input(msg, 's');
    
    if ~strcmp(answer, 'y')
        disp('Aborted.')
        return
    end
    
    
    %% Remove Preferences
    preferenceGroups = {'nansen_App', 'Nansen'};
    
    for i = 1:numel(preferenceGroups)
        if ispref(preferenceGroups{i})
            rmpref(preferenceGroups{i})
        end
    end
    
    
    %% Remove folders with userdata
    nansenRootPath = nansen.rootpath();

    % Remove folder with external toolboxes, project specific- and general
    % settings
    folderPath = {...
        fullfile(nansenRootPath, 'external', 'general_toolboxes'), ...
        fullfile(nansenRootPath, 'external', 'neuroscience_toolboxes'), ...
        fullfile(nansenRootPath, '_userdata', 'projects'), ...
        fullfile(nansenRootPath, '_userdata', 'settings') };
    
    backupPath = fullfile(nansenRootPath, '_userdata', 'backup', ...
        datestr(now, 'yyyy_mm_dd_HHMMSS'));
    
    for i = 1:numel(folderPath)
        
        iPath = folderPath{i};
        
        if ~exist(iPath, 'dir')
            continue
        end
        
        try
            rmpath(genpath(iPath))

            % Move project files and settings to a backup folder
            if contains(iPath, '_userdata')
                iPathTarget = strrep(iPath, ...
                    fullfile(nansenRootPath, '_userdata'), backupPath);
                movefile(iPath, iPathTarget)
            else
                rmdir(iPath, 's')
            end
            
            % Remake an empty directory
            mkdir(iPath)
            addpath(genpath(iPath))
            
        catch ME
            disp(ME.message)
        end
    end
    

    %% Show a confirmation message 
    disp('All settings and user data was removed')
    
end


function moveDirToBackup



end
