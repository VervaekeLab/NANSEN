function testToolbox(varargin)
% testToolbox - Run tests for NANSEN toolbox
   
    projectRootDirectory = nansentools.projectdir();
    addpath(genpath(fullfile(projectRootDirectory, 'code')))
    [status, teardownObjects] = setupNansenTestEnvironment("ClearAll", true); %#ok<ASGLU>
    if status ~= 0; error('Something went wrong'); end
   
    % Prepare
    projectRootDirectory = nansentools.projectdir();
    disp(projectRootDirectory)

    matbox.installRequirements(projectRootDirectory, "AgreeToLicenses", true)

    codecoverageFileList = getCodeCoverageFileList(fullfile(projectRootDirectory, "code")); % local function

    matbox.tasks.testToolbox(...
        projectRootDirectory, ...
        "SourceFolderName", "code", ...
        "CoverageFileList", codecoverageFileList, ...
        "CreateBadge", true, ...
        varargin{:} ...
        )
end

function fileList = getCodeCoverageFileList(sourceFolder)
    L = dir( fullfile(sourceFolder, '**', '*.m') );

    fileList = fullfile(string({L.folder}'), string({L.name}'));
    relativePaths = replace(fileList, sourceFolder + filesep, '');

    coverageIgnoreFile = fullfile(nansentools.projectdir(), 'tests', '.coverageignore');
    ignorePatterns = string(splitlines( fileread(coverageIgnoreFile) ));
    ignorePatterns(ignorePatterns=="") = [];

    keep = ~startsWith(relativePaths, ignorePatterns);
    fileList = fileList(keep);
end
