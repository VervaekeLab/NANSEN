function installDependencies(options)
% installDependencies - Install dependencies for the Nansen Toolbox
%
%   Note: Currently installs the FEX submission dependencies. 

%   Todo: Consolidate with AddonManager.

    arguments
        options.SaveUpdatedPath logical = logical.empty
    end

    dependencies = nansen.internal.setup.listDependencies;

    rootInstallationDirectory = nansen.common.constant.DefaultAddonPath();
    installationDirectory = fullfile(rootInstallationDirectory, 'FEX');
    if ~isfolder(installationDirectory); mkdir(installationDirectory); end
    
    installedAddons = {};

    for i = 1:height(dependencies)
        
        info = table2struct(dependencies(i,:));
        % Check if name is available (weak assumption, todo)
        if ismember( exist(info.Name, 'file'), [2,7] )
            fprintf('    %s already exists, skipping.\n', info.Name)
            continue
        end
        
        nansen.internal.setup.installFexSubmission(info, installationDirectory)
        fprintf('    Installed "%s" to %s\n', info.Name, installationDirectory)
        installedAddons{end+1} = info.Name; %#ok<AGROW>
    end

    if ~isempty(installedAddons)
        if isempty(options.SaveUpdatedPath)
            fprintf('The installed addons were added to MATLAB''s search path.\n')
            fprintf('Do you want to permanently save these changes the search path?\n')
            answer = input('Enter y or n: ', 's');
            if strcmp(answer, 'y')
                savepath()
            end
        elseif options.SaveUpdatedPath
            savepath()
        else
            % Do nothing
        end
    end
end
