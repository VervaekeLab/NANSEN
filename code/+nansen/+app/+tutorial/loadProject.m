
% Start a tutorial user session
userSession = nansen.internal.user.NansenUserSession.instance('tutorial');

% Allow user to select an existing project
S = ["Nansen - Two-photon Quickstart", ...
     "Allen Brain Observatory - Visual Coding (Neuropixels)", ...
     "Allen Brain Observatory - Visual Coding (Calcium Imaging)", ...
     "EBRAINS D&K - L2/3 + L5 Visual occlusion (Calcium Imaging)"];

S = ["Nansen - Two-photon Quickstart", ...
     "Allen Brain Observatory - Visual Coding (Calcium Imaging)"];

[selection, ok] = listdlg('ListString', S, 'ListSize', [360, 240]);

if ok
    switch S(selection)
        case "Nansen - Two-photon Quickstart"
            repositoryName = "Nansen_Demo";
            projectName = 'nansen_demo';

        case "Allen Brain Observatory - Visual Coding (Neuropixels)"
            repositoryName = "ABO-VisualCoding-Neuropixels-Test";

        case "Allen Brain Observatory - Visual Coding (Calcium Imaging)"
            repositoryName = "ABO-VisualCoding-TwoPhoton-Test";
            projectName = 'abo_ophys';

        case "EBRAINS D&K - L2/3 + L5 Visual occlusion (Calcium Imaging)"
            repositoryName = "EBRAINS-VisualOcclusion-TwoPhoton";
    end
end

if startsWith(S(selection), 'Allen Brain Observatory')
    addonManager = nansen.AddonManager();

    names = {addonManager.AddonList.Name};
    S = addonManager.AddonList(strcmp(names, "Brain Observatory Toolbox"));
    if ~S.IsInstalled
        fprintf('Downloading %s...', S.Name)
        addonManager.downloadAddon(S.Name)
        addonManager.addAddonToMatlabPath(S.Name)
        fprintf('Finished.\n')
    end
elseif startsWith(S(selection), 'Nansen - Two-photon Quickstart')
    warnState = warning('off', 'MATLAB:RMDIR:RemovedFromPath');
    warnCleanup = onCleanup(@() warning(warnState));
    disp('Installing two-photon addons...')
    nansen.internal.setup.installAddons()
    % Some users had problems where Yaml was not added to java path
    nansen.internal.setup.addYamlJarToJavaClassPath
end

% Check if project is already in the catalog
projectManager = userSession.getProjectManager();

if ~projectManager.containsProject(projectName)

    % Download target repository folder (todo: function)
    repositoryUrl = sprintf('https://github.com/NansenProjects/%s', repositoryName);
    installationLocation = fullfile(userpath, 'Nansen-Tutorial');
    fprintf("Downloading project ""%s""...\n", S(selection))
    repoTargetFolder = matbox.setup.internal.installGithubRepository(repositoryUrl, "InstallationLocation", installationLocation, "Update", true);
    
    L = dir(fullfile(repoTargetFolder, '*', 'project.nansen.json'));
    fprintf("Adding project ""%s"" to NANSEN...\n", S(selection))
    projectManager.importProject(L.folder);
    projectManager.changeProject(projectName);

    % Todo: Choose a datapath:
    %S = struct();
    %S.DataDirectory = fullfile(userpath, 'Nansen-Tutorial', 'Data', projectName);
    %S.DataDirectory_ = 'uigetdir';
    %[S, wasAborted] = tools.editStruct(S);

    dataDirectory = fullfile(userpath, 'Nansen-Tutorial', 'Data', projectName);
    
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
    if ~strcmp( projectManager.CurrentProject, projectName )
        projectManager.changeProject(projectName)
    end
end

nansen

% Todo: Clone BrainObservatoryToolbox
% Todo: Download manifests for selected dataset.
