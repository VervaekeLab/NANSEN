function reset()
%Reset Reset all settings of this software package. 


    %% Ask user if this is really desired.
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
    nansenRootPath = utility.path.getAncestorDir(nansen.rootpath, 1);

    % Remove folder with external toolboxes, project specific- and general
    % settings
    folderPath = {...
        fullfile(nansenRootPath, 'external', 'general_toolboxes'), ...
        fullfile(nansenRootPath, 'external', 'neuroscience_toolboxes'), ...
        fullfile(nansenRootPath, '_userdata', 'projects'), ...
        fullfile(nansenRootPath, '_userdata', 'settings') };
    
    for i = 1:numel(folderPath)
        
        iPath = folderPath{i};
        
        if ~exist(iPath, 'dir')
            continue
        end

        rmpath(genpath(iPath))
        rmdir(iPath, 's')
    
        % Remake an empty directory
        mkdir(iPath)
        addpath(genpath(iPath))
    end
    
    
    %% Show a confirmation message 
    disp('All settings and user data was removed')
    
end