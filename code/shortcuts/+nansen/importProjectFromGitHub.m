function importProjectFromGitHub(repositoryUrl, options)
% importProjectFromGitHub Import a project from a GitHub repository into Nansen
%
% Syntax:
%   nansen.importProjectFromGitHub(repositoryUrl)
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
%   - Requires an active user session
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
% See also nansen.config.project.importProjectFromGitHub

    arguments
        repositoryUrl (1,1) string
        options.GithubToken (1,1) string = missing % Not implemented yet
    end

    nansen.common.assertion.assertUserSessionActive()
    
    nansen.config.project.importProjectFromGitHub(repositoryUrl, options)
