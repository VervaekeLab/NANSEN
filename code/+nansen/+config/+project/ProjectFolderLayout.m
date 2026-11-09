classdef (Sealed) ProjectFolderLayout
%ProjectFolderLayout Version of the way a project folder is organised
%
%   CURRENT_VERSION identifies the layout that this code reads and writes.
%   A change that moves or renames anything in a project folder adds a step
%   to getMigrationSteps and sets CURRENT_VERSION to its Version.
%
%   The version is stored in the LayoutVersion field of project.nansen.json.
%   A project whose file has no such field holds FIRST_VERSION.
%
%   A project is brought up to date when a session first opens it, and not
%   when the session starts, because a project folder can be on a drive
%   that is not connected.
%
%   ProjectFolderLayout methods:
%       read              - Layout version stored in a project folder
%       write             - Store a layout version in a project folder
%       assertSupported   - Check that this code can work with a project folder
%       getMigrationSteps - Steps that bring an older project folder up to date
%       migrate           - Bring a project folder to the current layout
%
%   See also nansen.internal.migration.applyMigrationSteps,
%   nansen.internal.user.UserDataLayout

    properties (Constant)
        FIRST_VERSION = 1
        CURRENT_VERSION = 2
    end

    methods (Access = private)
        function obj = ProjectFolderLayout()
        %ProjectFolderLayout Not used; the class only groups static methods
        end
    end

    methods (Static)

        function layoutVersion = read(projectFolder)
        %read Layout version stored in a project folder
        %
        %   layoutVersion = read(projectFolder) returns the LayoutVersion
        %   field of project.nansen.json, or 0 when there is no such file
        %   or field.

            arguments
                projectFolder (1,1) string
            end

            layoutVersion = 0;

            filePath = getConfigFilePath(projectFolder);
            if ~isfile(filePath); return; end

            S = utility.io.loadjson(filePath);
            if isfield(S, 'LayoutVersion')
                layoutVersion = S.LayoutVersion;
            end
        end

        function write(projectFolder, layoutVersion)
        %write Store a layout version in a project folder
        %
        %   write(projectFolder) stores CURRENT_VERSION.
        %
        %   write(projectFolder, layoutVersion) stores layoutVersion.

            arguments
                projectFolder (1,1) string
                layoutVersion (1,1) double = nansen.config.project.ProjectFolderLayout.CURRENT_VERSION
            end

            filePath = getConfigFilePath(projectFolder);

            S = utility.io.loadjson(filePath);
            S.LayoutVersion = layoutVersion;
            utility.io.savejson(filePath, S);
        end

        function assertSupported(projectFolder)
        %assertSupported Check that this code can work with a project folder
        %
        %   Throws NANSEN:Project:LayoutNewer when a newer version of
        %   NANSEN organised the project folder, because this code would
        %   look for files in the wrong places and could write over data
        %   that it does not recognise.

            arguments
                projectFolder (1,1) string
            end

            import nansen.config.project.ProjectFolderLayout

            storedVersion = ProjectFolderLayout.read(projectFolder);

            if storedVersion > ProjectFolderLayout.CURRENT_VERSION
                error('NANSEN:Project:LayoutNewer', ...
                    ['A newer version of NANSEN organised the project in "%s" ' ...
                     '(layout %d, and this version handles up to layout %d). ' ...
                     'Update NANSEN and open the project again.'], ...
                    projectFolder, storedVersion, ProjectFolderLayout.CURRENT_VERSION)
            end
        end

        function steps = getMigrationSteps(projectFolder)
        %getMigrationSteps Steps that bring an older project folder up to date
        %
        %   steps = getMigrationSteps(projectFolder) returns the steps for
        %   that folder, in the form that
        %   nansen.internal.migration.applyMigrationSteps takes. The first
        %   step has Version FIRST_VERSION + 1, and the last one has
        %   Version CURRENT_VERSION.
        %
        %   A step names old folders as fixed text, because the constants
        %   of nansen.config.project.Project only describe the newest
        %   layout. A step runs again when its version could not be stored,
        %   so a second run must do nothing.

            steps = struct( ...
                'Version', {2}, ...
                'Description', {'move the Configurations folder into configurations'}, ...
                'Apply', {@() moveCapitalizedConfigurationFolder(projectFolder)} );
        end

        function migrate(projectFolder)
        %migrate Bring a project folder to the current layout
        %
        %   migrate(projectFolder) runs the migration steps that the
        %   project folder has not had. A folder without a
        %   project.nansen.json is left alone, since
        %   ProjectManager.upgradeProjects has to convert it first.
        %
        %   Throws NANSEN:Project:LayoutNewer as assertSupported does, and
        %   NANSEN:Migration:StepFailed when a step fails. The project
        %   should not be opened then, because this code expects the
        %   current layout.

            arguments
                projectFolder (1,1) string
            end

            import nansen.config.project.ProjectFolderLayout

            if ~isfile(getConfigFilePath(projectFolder)); return; end

            ProjectFolderLayout.assertSupported(projectFolder)
            if ProjectFolderLayout.read(projectFolder) >= ProjectFolderLayout.CURRENT_VERSION; return; end

            releaseLock = nansen.internal.migration.tryAcquireLock(projectFolder); %#ok<NASGU>

            % Another MATLAB can have finished while this one waited
            storedVersion = max(ProjectFolderLayout.read(projectFolder), ProjectFolderLayout.FIRST_VERSION);

            nansen.internal.migration.applyMigrationSteps(storedVersion, ...
                ProjectFolderLayout.getMigrationSteps(projectFolder), ...
                @(layoutVersion) recordVersion(projectFolder, layoutVersion))
        end
    end
end

function filePath = getConfigFilePath(projectFolder)
%getConfigFilePath Path of the configuration file of a project
    filePath = fullfile(projectFolder, nansen.config.project.Project.PROJECT_CONFIG_FILENAME);
end

function recordVersion(projectFolder, layoutVersion)
%recordVersion Store a version, and carry on if the project is read only
%
%   Without this, a project in a location that this user can not write to
%   could not be opened, also when a step had nothing to change there.

    try
        nansen.config.project.ProjectFolderLayout.write(projectFolder, layoutVersion)
    catch ME
        warning('NANSEN:Project:LayoutVersionNotStored', ...
            'NANSEN could not store the layout version of the project in "%s".\nReason: %s', ...
            projectFolder, ME.message)
    end
end

function moveCapitalizedConfigurationFolder(projectFolder)
%moveCapitalizedConfigurationFolder Bring Configurations into configurations
%
%   ProjectManager.getProjectCatalogPath used to save in Configurations, and
%   everything else in configurations. On a case sensitive file system
%   those are two folders. On any other, they are the same folder and there
%   is nothing to do. A file that both folders hold stays where it is.

    capitalizedFolder = fullfile(projectFolder, "Configurations");
    configurationFolder = fullfile(projectFolder, "configurations");

    listing = dir(projectFolder);
    entryNames = string({listing.name});

    if ~any(entryNames == "Configurations"); return; end

    hasConfigurationFolder = any(entryNames == "configurations");

    if ~hasConfigurationFolder
        if ~isfolder(configurationFolder)
            movefile(capitalizedFolder, configurationFolder)
        end
        return
    end

    listing = dir(capitalizedFolder);
    fileNames = setdiff(string({listing.name}), [".", ".."]);
    targetPaths = fullfile(configurationFolder, fileNames);
    fileNames = fileNames(~(isfile(targetPaths) | isfolder(targetPaths)));

    if ~isempty(fileNames)
        nansen.internal.system.moveFolderContents( ...
            capitalizedFolder, configurationFolder, EntryNames=reshape(fileNames, 1, []));
    end

    [~] = rmdir(capitalizedFolder); % Removed only if empty; the output keeps rmdir from throwing
end
