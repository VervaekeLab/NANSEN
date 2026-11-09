function problems = findInstallationProblems(options)
%findInstallationProblems List what is missing from this installation of NANSEN
%
%   problems = nansen.internal.setup.findInstallationProblems() returns a
%   string array with one element for each kind of problem it finds, and
%   an empty array when nothing is missing. It looks for folders of the
%   NANSEN code that are not on the MATLAB search path, and for required
%   community toolboxes that are not on it. nansen_install resolves both.
%
%   Code that migrates user data calls this before it changes anything. A
%   repository updated with git keeps the search path that was saved for
%   the earlier version, which does not hold the folders and toolboxes
%   that the current version needs.
%
%   problems = nansen.internal.setup.findInstallationProblems(Name=Value)
%   checks against the given values instead of the current ones:
%       CodeFolder    - Folder that holds the NANSEN code
%       SearchPath    - Folders on the search path
%       ManifestPaths - Dependency manifests that declare the requirements
%
%   See also nansen_install, nansen.internal.setup.verifyInstallation

    arguments
        options.CodeFolder (1,1) string = nansen.toolboxdir()
        options.SearchPath (1,:) string = strsplit(path(), pathsep)
        options.ManifestPaths (1,:) string = string.empty(1, 0)
    end

    problems = strings(1, 0);

    % genpath leaves out the folders that do not go on the search path,
    % such as package folders.
    codeFolders = string( strsplit(genpath(char(options.CodeFolder)), pathsep) );
    codeFolders(codeFolders == "") = [];

    missingFolders = setdiff(codeFolders, options.SearchPath, "stable");

    if ~isempty(missingFolders)
        % The top folders are enough to recognize the problem, and a folder
        % can hold many subfolders.
        folderNames = erase(missingFolders, options.CodeFolder + filesep);
        topFolderNames = unique(extractBefore(folderNames + filesep, filesep), "stable");
        problems(end+1) = "Folders of the NANSEN code not on the MATLAB search path: " ...
            + strjoin(topFolderNames, ", ");
    end

    requirements = nansen.internal.dependencies.resolveRequirements( ...
        DependencyTypes="community-toolbox", RequirementLevels="required", ...
        ManifestPaths=options.ManifestPaths);

    isMissing = ~[requirements.IsOnPath];

    if any(isMissing)
        problems(end+1) = "Required toolboxes not on the MATLAB search path: " ...
            + strjoin(string({requirements(isMissing).Name}), ", ");
    end
end
