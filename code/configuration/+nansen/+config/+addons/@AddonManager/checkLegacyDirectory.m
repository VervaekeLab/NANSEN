function checkLegacyDirectory()
% checkLegacyDirectory Check if the "legacy" directory exists and fix

    AM = nansen.AddonManager();

    legacyInstallationDirectory = AM.getDefaultInstallationDirLegacy();
    %legacyInstallationDirectory = AM.getDefaultInstallationDir();

    if isfolder(legacyInstallationDirectory)
        
        % Inform user that addons will to move it to the userpath.
        newInstallationDirectory = AM.getDefaultInstallationDir();
        %newInstallationDirectory = AM.getDefaultInstallationDirLegacy();

        msg = sprintf( ...
            "External toolboxes are currently located in the " + ...
            "NANSEN code repository. They will now be moved to the " + ...
            "following folder: %s", newInstallationDirectory);
        title = "External Add-Ons will be moved";

        uiwait( msgbox(msg, title, 'help') )
        
        % Copy folders and delete old ones.
        subFolders = {'general_toolboxes', 'neuroscience_toolboxes'};

        for i = 1:numel(subFolders)
            oldPath = fullfile(legacyInstallationDirectory, subFolders{i});
            newPath = fullfile(newInstallationDirectory, subFolders{i});
            
            % Remove java items from the javaclasspath
            utility.system.removeFilepathFromStaticJavaPath(oldPath)

            rmpath(genpath(oldPath))
            
            copyfile(oldPath, newPath)
            rmdir(oldPath, 's')

            addpath(genpath(newPath))
        end

        % Update path in AddonList
        for i = 1:numel(AM.AddonList)
            oldFilePath = AM.AddonList(i).FilePath;

            if ~isempty(oldFilePath)
                if contains(oldFilePath, legacyInstallationDirectory)
                    AM.AddonList(i).FilePath = replace(oldFilePath, ...
                        legacyInstallationDirectory, newInstallationDirectory);
                end
            end
        end
        AM.saveAddonList()
        
        % Update javaclasspath
        nansen.config.path.addYamlJarToJavaClassPath()
        nansen.config.path.addUiwidgetsJarToJavaClassPath()

        % Save changes to matlabs savepath.
        savepath()

        msg = sprintf( ...
            "External toolboxes have successfully been moved. " + ...
            "You might have to restart MATLAB for NANSEN to work as " + ...
            "before.");
        title = "External Add-Ons have been moved";

        uiwait( msgbox(msg, title, 'help') )
    end
end