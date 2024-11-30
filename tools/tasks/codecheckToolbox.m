function issues = codecheckToolbox()
% codecheckToolbox - Identify code issues for openMINDS_MATLAB toolbox

    nansentools.installMatBox("commit")
    projectRootDirectory = nansentools.projectdir();
    
    issues = matbox.tasks.codecheckToolbox(projectRootDirectory, ...
        "CreateBadge", true);
end
