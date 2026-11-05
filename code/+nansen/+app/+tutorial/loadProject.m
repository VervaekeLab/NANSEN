function loadProject(tutorial)

    arguments
        tutorial nansen.app.tutorial.enum.Tutorial {mustBeScalarOrEmpty} = nansen.app.tutorial.enum.Tutorial.empty
    end

    import nansen.app.tutorial.enum.Tutorial

    warnState = warning('off', 'Nansen:NoProjectsAvailable');
    warningCleanup = onCleanup(@() warning(warnState));
    userSession = nansen.internal.user.NansenUserSession.instance();

    if isempty(tutorial)
        tutorial = nansen.app.tutorial.uiSelectTutorialProject();
    end

    % We need the addonmanager to ensure all tutorial dependencies are installed
    addonManager = nansen.AddonManager();

    if startsWith(tutorial.Title, 'Allen Brain Observatory')

        addonManager.refreshManagedAddons( ...
            "SelectedModules", "nansen.module.ophys.twophoton")
        names = {addonManager.AddonList.Name};
        addonEntry = addonManager.AddonList(strcmp(names, "Brain Observatory Toolbox"));

        if isempty(addonEntry)
            error('NANSEN:Tutorial:MissingAddonDefinition', ...
                'Could not find the Brain Observatory Toolbox dependency definition.')
        end
        if ~addonEntry.IsInstalled
            fprintf('Downloading %s...', addonEntry.Name)
            addonManager.downloadAddon(addonEntry.Name)
            fprintf('Finished.\n')
        end

    elseif startsWith(tutorial.Title, 'Nansen - Two-photon Quickstart')
        warnState = warning('off', 'MATLAB:RMDIR:RemovedFromPath');
        warnCleanup = onCleanup(@() warning(warnState));

        disp('Installing two-photon addons...')
        addonManager.installMissingAddons( ...
            'nansen.module.ophys.twophoton', "ShowSummary", true)

        % Some users had problems where Yaml was not added to java path
        nansen.internal.setup.addYamlJarToJavaClassPath()
    end

    % Check if project is already in the catalog
    projectManager = userSession.getProjectManager();

    if ~projectManager.containsProject(tutorial.ProjectName)

        % Download target repository folder (todo: function)
        repositoryUrl = sprintf('https://github.com/NansenProjects/%s', tutorial.RepositoryName);
        installationLocation = fullfile(userpath, 'Nansen-Tutorial');
        fprintf("Downloading project ""%s""...\n", tutorial.Title)
        repoTargetFolder = matbox.setup.internal.installGithubRepository(...
            repositoryUrl, "InstallationLocation", installationLocation, "Update", true);

        L = dir(fullfile(repoTargetFolder, '*', 'project.nansen.json'));
        fprintf("Adding project ""%s"" to NANSEN...\n", tutorial.Title)
        projectManager.importProject(L.folder);
        projectManager.changeProject(tutorial.ProjectName);

        dataDirectory = fullfile(userpath, 'Nansen-Tutorial', 'Data', tutorial.ProjectName);

        project = projectManager.getCurrentProject();
        dlModel = project.DataLocationModel;
        for i = 1:dlModel.NumDataLocations
            item = dlModel.getItem(i);
            if ~isempty(item.RootPath)
                [~,folderName] = fileparts(item.RootPath.Value);
                item.RootPath.Value = fullfile(dataDirectory, folderName);
                project.DataLocationModel.replaceItem(item)
            end
        end
    else
        if ~strcmp( projectManager.CurrentProject, tutorial.ProjectName )
            projectManager.changeProject(tutorial.ProjectName)
        end
    end

    nansen()

    % Todo: Clone BrainObservatoryToolbox
    % Todo: Download manifests for selected dataset.
end
