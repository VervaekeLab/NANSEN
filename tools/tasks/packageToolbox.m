function nansen_packageToolbox(releaseType, versionString)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end
    
    nansentools.installMatBox("commit")

    projectRootDirectory = nansentools.projectdir();
    matbox.tasks.packageToolbox(projectRootDirectory, releaseType, versionString, ...
        "ToolboxShortName", "NANSEN", ...
        "SourceFolderName", "code")
end
