function testToolbox(varargin)
% testToolbox - Run tests for NANSEN toolbox
   
    projectRootDirectory = nansentools.projectdir();
    addpath(genpath(fullfile(projectRootDirectory, 'code')))
    [status, teardownObjects] = setupNansenTestEnvironment("ClearAll", true); %#ok<ASGLU>
    if status ~= 0; error('Something went wrong'); end
   
    % Prepare
    projectRootDirectory = nansentools.projectdir();
    matbox.installRequirements(projectRootDirectory, "AgreeToLicenses", true)

    matbox.tasks.testToolbox(...
        projectRootDirectory, ...
        "SourceFolderName", "code", ...
        "CreateBadge", true, ...
        "Verbosity", "Concise", ...
        varargin{:} ...
        )
end

