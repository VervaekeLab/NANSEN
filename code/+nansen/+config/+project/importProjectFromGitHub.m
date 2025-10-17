function project = importProjectFromGitHub(repositoryUrl, options)
% importProjectFromGitHub Import a project from a GitHub repository into Nansen
%
% Syntax:
%   nansen.config.project.importProjectFromGitHub(repositoryUrl)
%
% Description:
%   This function downloads a specified GitHub repository containing a 
%   Nansen project and installs it into the user's local Nansen directory. 
%   After the repository is downloaded, the function locates the project 
%   file and imports it into the Nansen project manager, setting it as the 
%   active project.
%
% Inputs:
%   repositoryUrl (string) - The URL of the GitHub repository containing 
%                            the Nansen project.
%
% Notes:
%   - The project folder is downloaded to the default installation 
%     location under the user's path in the 'Nansen/Projects' directory.
%   - The function expects the project to contain a 'project.nansen.json' 
%     file to be successfully imported.
%   - If the project already exists, it will be updated with the latest 
%     version from GitHub.
%
% Example:
%   importProjectFromGitHub("https://github.com/username/project-repo")
%
% See also:
%   matbox.setup.internal.installGithubRepository, projectManager.importProject


    arguments
        repositoryUrl (1,1) string
        options.NansenUserName (1,1) string = "default"
        options.GithubToken (1,1) string = missing % Not implemented yet
    end

    import nansen.internal.user.NansenUserSession

    % Download target repository folder 
    installationLocation = fullfile(userpath, 'Nansen', 'Projects');
    repoTargetFolder = matbox.setup.internal.installGithubRepository(repositoryUrl, "InstallationLocation", installationLocation, "Update", true);
    if ismissing(options.NansenUserName)
        nansen.common.assertion.assertUserSessionActive()
        userSession = NansenUserSession.instance("", "nocreate");
    else
        userSession = NansenUserSession.instance(options.NansenUserName);
    end
    projectManager = userSession.getProjectManager();

    % Add project to nansen
    L = dir(fullfile(repoTargetFolder, '*', 'project.nansen.json'));
    projectName = projectManager.importProject(L.folder);
    projectManager.changeProject(projectName);
end
