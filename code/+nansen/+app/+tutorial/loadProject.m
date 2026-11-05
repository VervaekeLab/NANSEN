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
            "SelectedModules", "nansen.module.twophoton")
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
            'nansen.module.twophoton', "ShowSummary", true)

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
        renameTwoPhotonModulePackage(L.folder)
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

function renameTwoPhotonModulePackage(projectFolder)
%renameTwoPhotonModulePackage Point a project's module list at nansen.module.twophoton
%
%   The two-photon tutorial project (repository NansenProjects/Nansen_Demo)
%   lists the two-photon module in Preferences.DataModule of
%   project.nansen.json as nansen.module.ophys.twophoton. The module's
%   package is nansen.module.twophoton, and nansen.module.Module.fromName
%   finds a module only by its package name, so the entry is rewritten
%   before the project is imported. Other entries are left unchanged.

    arguments
        projectFolder (1,1) string {mustBeFolder}
    end

    oldPackageName = "nansen.module.ophys.twophoton";
    newPackageName = "nansen.module.twophoton";

    specificationFilePath = fullfile(projectFolder, "project.nansen.json");
    projectSpecification = utility.io.loadjson(specificationFilePath);
    if ~isfield(projectSpecification, "Preferences") ...
            || ~isfield(projectSpecification.Preferences, "DataModule")
        return
    end

    moduleNames = string(projectSpecification.Preferences.DataModule);
    isOldPackageName = moduleNames == oldPackageName;
    if any(isOldPackageName)
        moduleNames(isOldPackageName) = newPackageName;
        % A cell array is encoded as a JSON array for any number of names.
        projectSpecification.Preferences.DataModule = cellstr(moduleNames);
        utility.io.savejson(specificationFilePath, projectSpecification)
    end
end
