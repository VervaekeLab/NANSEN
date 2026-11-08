classdef ProjectFolderUpgradeTest < matlab.unittest.TestCase
    %ProjectFolderUpgradeTest What a failed upgrade of a project folder leaves behind
    %
    %   The upgrade removes a project from the catalog before it creates the
    %   project again in the current layout. A failure has to put the entry
    %   back, or the project can no longer be reached from the project
    %   manager and its upgrade is never tried again.
    %
    %   A hyphen makes a project name invalid as a package folder, so
    %   createProject fails for such a name after the project has been
    %   removed from the catalog.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.project.ProjectFolderUpgradeTest')

    properties
        ProjectManager
        RootFolder (1,1) string
    end

    methods (TestMethodSetup)
        function useIsolatedCatalog(testCase)
        %useIsolatedCatalog Point the manager at a catalog of its own

            % The upgrade keeps its backups under the userpath
            testCase.assumeNotEmpty(userpath())

            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.RootFolder = string(fixture.Folder);

            % The project manager is a singleton, so it is reset onto a
            % temporary preference directory for the duration of a test and
            % put back afterwards.
            testCase.ProjectManager = ...
                nansen.config.project.ProjectManager.instance(fixture.Folder, 'reset');

            testCase.addTeardown(@() ...
                nansen.config.project.ProjectManager.instance(nansen.prefdir, 'reset'));
        end
    end

    methods (Test)

        function testFailedUpgradeKeepsTheCatalogEntry(testCase)
            [projectName, projectFolder] = testCase.createOldFormatProject("not-an-identifier");
            testCase.ProjectManager.addProject(projectName, 'A project', projectFolder)

            testCase.upgradeExpectingCreationFailure(projectFolder)

            entry = testCase.ProjectManager.getProject(projectName);
            testCase.verifyEqual(entry.Path, projectFolder)
            testCase.verifyEqual(entry.Description, 'A project')
        end

        function testFailedUpgradeKeepsAnEntryWithoutDescription(testCase)
            [projectName, projectFolder] = testCase.createOldFormatProject("not-an-identifier");
            testCase.ProjectManager.addProject(projectName, '', projectFolder)

            testCase.upgradeExpectingCreationFailure(projectFolder)

            testCase.verifyTrue(testCase.ProjectManager.containsProject(projectName))
        end

        function testFailedUpgradeRestoresTheProjectFolder(testCase)
            [projectName, projectFolder] = testCase.createOldFormatProject("not-an-identifier");
            testCase.ProjectManager.addProject(projectName, 'A project', projectFolder)

            testCase.upgradeExpectingCreationFailure(projectFolder)

            testCase.verifyTrue(testCase.hasOldLayout(projectFolder))
        end

        function testFailedUpgradeAddsNoEntryForAProjectOutsideTheCatalog(testCase)
        %testFailedUpgradeAddsNoEntryForAProjectOutsideTheCatalog
        %
        %   importProject upgrades a folder that is not in the catalog yet.

            [~, projectFolder] = testCase.createOldFormatProject("not-an-identifier");

            testCase.upgradeExpectingCreationFailure(projectFolder)

            testCase.verifyEqual(testCase.ProjectManager.NumProjects, 0)
        end

        function testFailureAfterProjectIsCreatedLeavesOneEntry(testCase)
        %testFailureAfterProjectIsCreatedLeavesOneEntry
        %
        %   This folder has no session methods to move, so the upgrade fails
        %   after createProject has added the project to the catalog again.

            [projectName, projectFolder] = testCase.createOldFormatProject("upgrade_test");
            testCase.ProjectManager.addProject(projectName, 'A project', projectFolder)

            testCase.verifyError( ...
                @() nansen.internal.refactor.reorganizeProjectFolder( ...
                    projectFolder, testCase.ProjectManager), ?MException)

            testCase.verifyEqual(testCase.ProjectManager.ProjectNames, string(projectName))
            testCase.verifyTrue(testCase.hasOldLayout(projectFolder))
        end
    end

    methods (Access = private)

        function [projectName, projectFolder] = createOldFormatProject(testCase, namePrefix)
        %createOldFormatProject Create a project folder with the old layout
        %
        %   The unique name keeps the teardown from touching the backups of
        %   any other project under the userpath.

            uniqueSuffix = replace(nansen.util.getuuid(), "-", "_");
            projectName = char(namePrefix + "_" + uniqueSuffix);
            projectFolder = char(fullfile(testCase.RootFolder, projectName));
            mkdir(projectFolder)

            ProjectConfiguration = struct('Name', projectName, ...
                'Description', 'A project', 'Path', projectFolder);
            save(fullfile(projectFolder, 'nansen_project_configuration.mat'), ...
                'ProjectConfiguration')

            testCase.addTeardown(@deleteUpgradeBackups, projectName)
        end

        function upgradeExpectingCreationFailure(testCase, projectFolder)
            testCase.verifyError( ...
                @() nansen.internal.refactor.reorganizeProjectFolder( ...
                    projectFolder, testCase.ProjectManager), ...
                "Nansen:CreateProjectFailed")
        end
    end

    methods (Static, Access = private)

        function tf = hasOldLayout(projectFolder)
            tf = isfile(fullfile(projectFolder, 'nansen_project_configuration.mat')) ...
                && ~isfile(fullfile(projectFolder, nansen.common.constant.ProjectConfigFilename));
        end
    end
end

function deleteUpgradeBackups(projectName)
%deleteUpgradeBackups Remove the backups that an upgrade made under the userpath

    backups = dir(fullfile(userpath, "Nansen", "Backup", "*", "Projects", "*_" + projectName));

    for i = 1:numel(backups)
        rmdir(fullfile(backups(i).folder, backups(i).name), "s")
    end
end
