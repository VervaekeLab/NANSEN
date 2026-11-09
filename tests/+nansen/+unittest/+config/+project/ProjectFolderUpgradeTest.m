classdef ProjectFolderUpgradeTest < matlab.unittest.TestCase
    %ProjectFolderUpgradeTest What the upgrade of a project folder leaves behind
    %
    %   The upgrade removes a project from the catalog before it creates the
    %   project again in the current layout. A failure has to put the entry
    %   back, or the project can no longer be reached from the project
    %   manager and its upgrade is never tried again. A success has to keep
    %   the settings of the project.
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

    properties (Constant)
        CustomDataLocationName = 'CustomRawdata'
        CustomVariableName = 'customVariable'
        TwoPhotonModuleName = "nansen.module.ophys.twophoton"
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

        function testFailedRollbackRestoresFolder(testCase)
        %testFailedRollbackRestoresFolder Each step of the rollback runs
        %
        %   A catalog that refuses the entry must not cost the project its
        %   folder, and the error has to say where the backup is.

            [projectName, projectFolder] = testCase.createOldFormatProject("not-an-identifier");
            testCase.ProjectManager.addProject(projectName, 'A project', projectFolder)
            testCase.addFieldThatNewEntriesLack()

            exception = testCase.captureUpgradeError(projectFolder);

            testCase.verifyEqual(string(exception.identifier), ...
                "NANSEN:ProjectManager:ProjectRollbackFailed")
            testCase.verifySubstring(string(exception.message), fullfile("Nansen", "Backup"))
            testCase.verifyEqual(string(exception.cause{1}.identifier), ...
                "Nansen:CreateProjectFailed")
            testCase.verifyTrue(testCase.hasOldLayout(projectFolder))
        end

        function testFailedUpgradeWarnsWithReason(testCase)
        %testFailedUpgradeWarnsWithReason The warning names cause and remedy

            testCase.assumeEmpty(nansen.internal.setup.findInstallationProblems(), ...
                "An incomplete installation skips the upgrade")

            testCase.stubUpgradeDialogs()
            [projectName, projectFolder] = testCase.createOldFormatProject("not-an-identifier");
            testCase.ProjectManager.addProject(projectName, 'A project', projectFolder)

            testCase.verifyWarning(@() testCase.ProjectManager.upgradeProjects(), ...
                "NANSEN:ProjectManager:ProjectUpgradeFailed")

            warningMessage = string(lastwarn());
            testCase.verifySubstring(warningMessage, "at line")
            testCase.verifySubstring(warningMessage, "If the folder still has the old layout")
            testCase.verifySubstring(warningMessage, string(nansen.rootpath()))
        end

        function testUpgradeKeepsDataLocations(testCase)
        %testUpgradeKeepsDataLocations The catalog of the project is used
        %
        %   createProject writes new catalogs before the catalogs of the
        %   project are copied in, and a model uses a json file whenever
        %   there is one. DataLocationModel can only be constructed for the
        %   current project, so the files are checked here.

            [~, projectFolder] = testCase.createUpgradableProject();

            testCase.upgrade(projectFolder)

            configurationFolder = fullfile(projectFolder, 'configurations');
            testCase.verifyFalse(isfile(fullfile(configurationFolder, 'datalocation_settings.json')))

            S = load(fullfile(configurationFolder, 'datalocation_settings.mat'));
            testCase.verifyEqual(S.Data(1).Name, testCase.CustomDataLocationName)
        end

        function testUpgradeKeepsDataVariables(testCase)
            [projectName, projectFolder] = testCase.createUpgradableProject();

            testCase.upgrade(projectFolder)

            project = testCase.ProjectManager.getProjectObject(projectName);
            variableNames = {project.VariableModel.Data.VariableName};
            testCase.verifyTrue(any(strcmp(variableNames, testCase.CustomVariableName)))
        end

        function testUpgradeKeepsTwoPhotonModule(testCase)
        %testUpgradeKeepsTwoPhotonModule The module is listed and loaded
        %
        %   A project in the old layout lists no modules, and all of them
        %   used this one.

            [projectName, projectFolder] = testCase.createUpgradableProject();

            testCase.upgrade(projectFolder)

            project = testCase.ProjectManager.getProjectObject(projectName);
            includedModules = string({project.IncludedModules.ID});
            testCase.verifyTrue(any(includedModules == testCase.TwoPhotonModuleName))
        end

        function testNewCatalogStaysWithoutOldOne(testCase)
        %testNewCatalogStaysWithoutOldOne A catalog is only replaced by a copy

            [projectName, projectFolder] = testCase.createUpgradableProject();
            delete(fullfile(projectFolder, 'Configurations', 'filepath_settings.mat'))

            testCase.upgrade(projectFolder)

            project = testCase.ProjectManager.getProjectObject(projectName);
            testCase.verifyTrue(endsWith(string(project.VariableModel.FilePath), ".json"))
        end
    end

    methods (Access = private)

        function [projectName, projectFolder] = createUpgradableProject(testCase)
        %createUpgradableProject Create a catalogued project in the old layout
        %
        %   The project has the folders that the upgrade copies, and a
        %   data location and a variable that a new project does not have.

            [projectName, projectFolder] = testCase.createOldFormatProject("upgrade_test");
            testCase.ProjectManager.addProject(projectName, 'A project', projectFolder)

            mkdir(fullfile(projectFolder, 'Session Methods', ['+', projectName]))
            mkdir(fullfile(projectFolder, 'Metadata Tables', ['+', projectName], '+tablevar'))

            configurationFolder = fullfile(projectFolder, 'Configurations');
            mkdir(configurationFolder)

            dataLocationFile = fullfile(configurationFolder, 'datalocation_settings.mat');
            nansen.config.initializeDataLocationModel(dataLocationFile);
            S = load(dataLocationFile);
            S.Data(1).Name = testCase.CustomDataLocationName;
            save(dataLocationFile, '-struct', 'S')

            variableFile = fullfile(configurationFolder, 'filepath_settings.mat');
            variableModel = nansen.config.varmodel.VariableModel(variableFile);
            variableModel.insertItem(variableModel.getDefaultItem(testCase.CustomVariableName));
            variableModel.save()
        end

        function upgrade(testCase, projectFolder)
            nansen.internal.refactor.reorganizeProjectFolder(projectFolder, testCase.ProjectManager)
        end

        function addFieldThatNewEntriesLack(testCase)
        %addFieldThatNewEntriesLack Make the catalog refuse any new entry
        %
        %   A struct array only accepts an element with the same fields as
        %   its own.

            catalog = testCase.ProjectManager.Catalog;
            [catalog.UnknownField] = deal([]);
            testCase.ProjectManager.Catalog = catalog;
        end

        function exception = captureUpgradeError(testCase, projectFolder)
        %captureUpgradeError Run the upgrade and return the error it raises

            exception = [];
            try
                nansen.internal.refactor.reorganizeProjectFolder( ...
                    projectFolder, testCase.ProjectManager)
            catch exception
                % The error is the result that the caller inspects
            end
            testCase.fatalAssertNotEmpty(exception, "The upgrade did not fail")
        end

        function stubUpgradeDialogs(testCase)
        %stubUpgradeDialogs Replace the dialogs that confirm an upgrade
        %
        %   upgradeProjects waits for an answer in modal dialogs.

            import matlab.unittest.fixtures.PathFixture

            stubFolder = fullfile(testCase.RootFolder, "dialog_stubs");
            mkdir(stubFolder)

            stubNames = ["msgbox", "uiwait", "questdlg"];
            stubCode = [ ...
                "function handle = msgbox(varargin)" + newline + "    handle = [];" + newline + "end", ...
                "function uiwait(varargin)" + newline + "end", ...
                "function answer = questdlg(varargin)" + newline + "    answer = 'Confirm';" + newline + "end"];

            for i = 1:numel(stubNames)
                utility.filewrite(char(fullfile(stubFolder, stubNames(i) + ".m")), char(stubCode(i)))
            end

            testCase.applyFixture(PathFixture(char(stubFolder)));
        end

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
