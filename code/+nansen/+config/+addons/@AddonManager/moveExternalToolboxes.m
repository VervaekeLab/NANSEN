function moveExternalToolboxes(obj)
% moveExternalToolboxes Check if the "legacy" directory exists and fix
%
%   Originally, external toolboxes were installed into the nansen
%   repository folder. These should be stored in a separate location and
%   will therefore be moved to MATLAB's userpath.

    legacyInstallationDirectory = obj.getDefaultInstallationDirLegacy();
    %legacyInstallationDirectory = AM.getDefaultInstallationDir();

    if isfolder(legacyInstallationDirectory)
        
        % Inform user that addons will be moved to the userpath.
        newInstallationDirectory = obj.getDefaultInstallationDir();
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
            
            if ~isfolder( oldPath ); continue; end
            
            % Remove java items from the javaclasspath
            nansen.internal.setup.java.removeFilepathFromStaticJavaPath(oldPath)

            rmpath(genpath(oldPath))
            
            copyfile(oldPath, newPath)
            rmdir(oldPath, 's')

            addpath(genpath(newPath))
        end

        % Update path in AddonList
        for i = 1:numel(obj.AddonList)
            oldFilePath = obj.AddonList(i).FilePath;

            if ~isempty(oldFilePath)
                if contains(oldFilePath, legacyInstallationDirectory)
                    obj.AddonList(i).FilePath = replace(oldFilePath, ...
                        legacyInstallationDirectory, newInstallationDirectory);
                end
            end
        end
        obj.saveAddonList()
        
        % Update javaclasspath
        nansen.internal.setup.addYamlJarToJavaClassPath()
        nansen.internal.setup.addUiwidgetsJarToJavaClassPath()

        % Save changes to matlabs savepath.
        savepath()

        msg = sprintf( ...
            "External toolboxes have successfully been moved. " + ...
            "You might have to restart MATLAB for NANSEN to work as " + ...
            "before.");
        title = "External Add-Ons have been moved";

        uiwait( msgbox(msg, title, 'help') )

        rmpath(legacyInstallationDirectory)
        try
            rmdir(legacyInstallationDirectory)
        catch ME
            warning(ME.message)
        end
    end
end
