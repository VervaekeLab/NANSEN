function issues = codecheckToolbox()
% codecheckToolbox - Identify code issues for openMINDS_MATLAB toolbox

    projectRootDirectory = nansentools.projectdir();
    
    codeAnalysisFileList = getCodeAnalysisFileList(fullfile(projectRootDirectory)); % local function

    issues = matbox.tasks.codecheckToolbox(projectRootDirectory, ...
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
