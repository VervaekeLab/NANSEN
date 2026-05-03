function issues = codecheckToolbox(varargin)
% codecheckToolbox - Identify code issues for openMINDS_MATLAB toolbox

    projectRootDirectory = nansentools.projectdir();
    
    codeAnalysisFileList = getCodeAnalysisFileList(fullfile(projectRootDirectory, 'code')); % local function

    issues = matbox.tasks.codecheckToolbox(projectRootDirectory, ...
        varargin{:}, ...
        "FoldersToCheck", string.empty, ... % Ensure we are not using matbox default
        "CreateBadge", true, ...
        "FilesToCheck", codeAnalysisFileList);
end

function fileList = getCodeAnalysisFileList(sourceFolder)
    L = dir( fullfile(sourceFolder, '**', '*.m') );

    fileList = fullfile(string({L.folder}'), string({L.name}'));

    ignoreFile = fullfile(nansentools.projectdir(), 'tests', '.coverageignore');
    ignorePatterns = string(splitlines( fileread(ignoreFile) ));
    ignorePatterns(ignorePatterns=="") = [];

    keep = ~contains(fileList, ignorePatterns);
    fileList = fileList(keep);
end
