function testToolbox(varargin)
% testToolbox - Run tests for NANSEN toolbox
   
    projectRootDirectory = nansentools.projectdir();
    addpath(genpath(fullfile(projectRootDirectory, 'code')))
    [status, teardownObjects] = setupNansenTestEnvironment(ClearAll=true); %#ok<ASGLU>
    if status ~= 0; error('Something went wrong'); end
   
    % Prepare
    nansentools.installMatBox("commit")
    projectRootDirectory = nansentools.projectdir();
    % matbox.installRequirements(projectRootDirectory) % No requirements...

    matbox.tasks.testToolbox(...
        projectRootDirectory, ...
        "CreateBadge", true, ...
        "Verbosity", "Concise", ...
        varargin{:} ...
        )
end

