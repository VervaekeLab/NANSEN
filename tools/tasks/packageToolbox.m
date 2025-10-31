function [newVersion, mltbxPath] = packageToolbox(releaseType, versionString, varargin)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end
    arguments (Repeating)
        varargin
    end

    if exist('+matbox/installRequirements', 'file') ~= 2
        nansentools.installMatBox("commit")
    end

    projectRootDirectory = nansentools.projectdir();
    [newVersion, mltbxPath] = matbox.tasks.packageToolbox(projectRootDirectory, releaseType, versionString, ...
        varargin{:}, ...
        "ToolboxShortName", "NANSEN", ...
        "SourceFolderName", "code");
end
