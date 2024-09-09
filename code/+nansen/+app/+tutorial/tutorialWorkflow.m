

% Start a tutorial user session
userSession = nansen.internal.user.NansenUserSession.instance('tutorial');

% Allow user to select an existing project
S = ["Allen Brain Observatory - Visual Coding (Neuropixels)", ...
     "Allen Brain Observatory - Visual Coding (Calcium Imaging)", ...
     "EBRAINS D&K - L2/3 + L5 Visual occlusion (Calcium Imaging)"];

[selection, ok] = listdlg('ListString',S, 'ListSize', [360, 240]);

if ok
    switch S(selection)
        case "Allen Brain Observatory - Visual Coding (Neuropixels)"
            repositoryName = "ABO-VisualCoding-Neuropixels-Test";

        case "Allen Brain Observatory - Visual Coding (Calcium Imaging)"
            repositoryName = "ABO-VisualCoding-TwoPhoton-Test";
       
        case "EBRAINS D&K - L2/3 + L5 Visual occlusion (Calcium Imaging)"
            repositoryName = "EBRAINS-VisualOcclusion-TwoPhoton";
        
        
    end
end

% Download target repository folder
repositoryUrl = sprintf('https://github.com/NansenProjects/%s', repositoryName);
installationLocation = fullfile(userpath, 'Nansen-Tutorial');
repoTargetFolder = setuptools.internal.installGithubRepository(repositoryUrl, "InstallationLocation", installationLocation, "Update", true);

L = dir(fullfile(repoTargetFolder, '*', 'project.nansen.json'));

projectManager = userSession.getProjectManager();
projectManager.importProject(L.folder);

nansen



