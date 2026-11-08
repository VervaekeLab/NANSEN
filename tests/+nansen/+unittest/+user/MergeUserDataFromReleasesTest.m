classdef MergeUserDataFromReleasesTest < matlab.unittest.TestCase
    %MergeUserDataFromReleasesTest Merging the user data of several MATLAB releases
    %
    %   Every test builds its preference directories and its user data
    %   root in a temporary folder.
    %
    %   Run tests:
    %       runtests('nansen.unittest.user.MergeUserDataFromReleasesTest')

    properties
        PreferenceRoot (1,1) string
        UserDataRoot (1,1) string
        ProjectRoot (1,1) string
    end

    methods (TestMethodSetup)
        function createFolders(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);

            root = string(fixture.Folder);
            testCase.PreferenceRoot = fullfile(root, "preferences");
            testCase.UserDataRoot = fullfile(root, "user_data");
            testCase.ProjectRoot = fullfile(root, "project_folders");

            mkdir(testCase.PreferenceRoot)
            mkdir(testCase.ProjectRoot)
        end
    end

    methods (Test) % What is merged

        function testDryRunChangesNothing(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));

            report = testCase.merge(Apply=false);

            testCase.verifyEqual(numel(report), 1)
            testCase.verifyFalse(isfolder(testCase.UserDataRoot))
            testCase.verifyTrue(isfile(testCase.profilePath("R2024b", "projects", "project_catalog.mat")))
        end

        function testProjectsFromAllReleasesAreCombined(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));
            testCase.writeCatalog("R2026a", "default", testCase.entry("beta"));

            testCase.merge();

            testCase.verifyEqual(sort(string({testCase.readCatalog("default").Name})), ["alpha", "beta"])
        end

        function testEachProfileGetsItsOwnCatalog(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));
            testCase.writeCatalog("R2024b", "other", testCase.entry("beta"));

            testCase.merge();

            testCase.verifyEqual(string({testCase.readCatalog("default").Name}), "alpha")
            testCase.verifyEqual(string({testCase.readCatalog("other").Name}), "beta")
        end

        function testProfilesOptionLimitsTheMerge(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));
            testCase.writeCatalog("R2024b", "other", testCase.entry("beta"));

            testCase.merge(Profiles="other");

            testCase.verifyFalse(isfolder(fullfile(testCase.UserDataRoot, "default")))
            testCase.verifyTrue(isfolder(testCase.profilePath("R2024b", "projects", "", "default")))
        end

        function testProfileWithoutDataIsSkipped(testCase)
            mkdir(testCase.profilePath("R2024b", "projects"))

            report = testCase.merge();

            testCase.verifyEmpty(report)
            testCase.verifyFalse(isfolder(fullfile(testCase.UserDataRoot, "default")))
            testCase.verifyTrue(isfolder(testCase.profilePath("R2024b", "projects")))
        end

        function testSameProjectInSeveralReleasesIsAddedOnce(testCase)
            projectPath = testCase.projectFolder("alpha");
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha", projectPath));
            testCase.writeCatalog("R2026a", "default", testCase.entry("alpha", projectPath + filesep));

            report = testCase.merge();

            testCase.verifyEqual(numel(testCase.readCatalog("default")), 1)
            testCase.verifyEmpty(report.ProjectConflicts)
            testCase.verifyEqual(report.Projects.Releases, ["R2024b", "R2026a"])
        end

        function testEntriesGetTheFormTheProjectManagerUses(testCase)
        %testEntriesGetTheFormTheProjectManagerUses Older catalogs are converted
        %
        %   Catalogs from older versions have no ShortName field, can have
        %   a Preferences field, and can hold strings.

            legacyEntry = struct('Name', "alpha", 'Description', "A project", ...
                'Path', string(testCase.projectFolder("alpha")), 'Preferences', struct());
            testCase.writeCatalog("R2024b", "default", legacyEntry);

            testCase.merge();

            catalog = testCase.readCatalog("default");
            testCase.verifyEqual(fieldnames(catalog), {'Name'; 'ShortName'; 'Description'; 'Path'})
            testCase.verifyEqual(catalog.ShortName, 'alpha')
            testCase.verifyClass(catalog.Path, 'char')
            testCase.verifyClass(catalog.Name, 'char')
        end

        function testFoldersThatASessionSetAsideAreGathered(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"), "projects.unmigrated");
            testCase.writeFile(testCase.profilePath("R2024b", "settings.unmigrated_2", "app.mat"), "kept");

            testCase.merge();

            testCase.verifyEqual(string({testCase.readCatalog("default").Name}), "alpha")
            testCase.verifyTrue(isfile(testCase.targetPath("settings", "app.mat")))
        end
    end

    methods (Test) % What is already in the user data directory

        function testExistingCatalogEntriesAreKept(testCase)
            keptPath = testCase.projectFolder("kept");
            otherPath = testCase.projectFolder("other");
            testCase.writeTargetCatalog(testCase.entry("alpha", keptPath));
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha", otherPath));

            report = testCase.merge();

            testCase.verifyEqual(testCase.readCatalog("default").Path, char(keptPath))
            testCase.verifyEqual(report.ProjectConflicts.OtherPath, otherPath)
        end

        function testExistingEntriesStayAndNewOnesAreAdded(testCase)
            testCase.writeTargetCatalog(testCase.entry("alpha"));
            testCase.writeCatalog("R2024b", "default", testCase.entry("beta"));

            testCase.merge();

            testCase.verifyEqual(string({testCase.readCatalog("default").Name}), ["alpha", "beta"])
        end

        function testExistingFileIsNotOverwritten(testCase)
            testCase.writeFile(testCase.targetPath("settings", "app.mat"), "in use");
            testCase.writeFile(testCase.profilePath("R2024b", "settings", "app.mat"), "from a release");

            report = testCase.merge();

            testCase.verifyEqual(string(fileread(testCase.targetPath("settings", "app.mat"))), "in use")
            testCase.verifyEqual(report.FileConflicts.UsedCopy, "user data directory")
        end
    end

    methods (Test) % Choosing between releases

        function testAProjectFolderThatExistsIsPreferred(testCase)
            existingPath = testCase.projectFolder("exists");
            missingPath = fullfile(testCase.ProjectRoot, "missing");

            % The catalog that names the missing folder is the newest
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha", existingPath));
            testCase.setModified(testCase.profilePath("R2024b", "projects", "project_catalog.mat"), 2020);
            testCase.writeCatalog("R2026a", "default", testCase.entry("alpha", missingPath));

            report = testCase.merge();

            testCase.verifyEqual(testCase.readCatalog("default").Path, char(existingPath))
            testCase.verifyEqual(report.ProjectConflicts.OtherPath, missingPath)
        end

        function testMostRecentlySavedCatalogDecidesBetweenFolders(testCase)
            olderPath = testCase.projectFolder("older");
            newerPath = testCase.projectFolder("newer");
            testCase.writeCatalog("R2026a", "default", testCase.entry("alpha", olderPath));
            testCase.setModified(testCase.profilePath("R2026a", "projects", "project_catalog.mat"), 2020);
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha", newerPath));

            testCase.merge();

            testCase.verifyEqual(testCase.readCatalog("default").Path, char(newerPath))
        end

        function testNewestContentIsUsed(testCase)
            olderFile = testCase.profilePath("R2026a", "custom_options", "preset.mat");
            newerFile = testCase.profilePath("R2024b", "custom_options", "preset.mat");
            testCase.writeFile(olderFile, "older");
            testCase.setModified(olderFile, 2020);
            testCase.writeFile(newerFile, "newer");

            report = testCase.merge();

            testCase.verifyEqual(string(fileread(testCase.targetPath("custom_options", "preset.mat"))), "newer")
            testCase.verifyEqual(report.FileConflicts.UsedCopy, "R2024b")
            testCase.verifyEqual(report.FileConflicts.OtherCopies, "R2026a")
        end

        function testCopiesWithTheSameContentAreDatedByTheOldest(testCase)
        %testCopiesWithTheSameContentAreDatedByTheOldest An install date is not an edit
        %
        %   Installing R2026a copied the file from R2025b and dated the
        %   copy by the installation. R2024b changed its file in between.

            original = testCase.profilePath("R2025b", "custom_options", "preset.mat");
            installCopy = testCase.profilePath("R2026a", "custom_options", "preset.mat");
            changed = testCase.profilePath("R2024b", "custom_options", "preset.mat");

            testCase.writeFile(original, "old content");
            testCase.setModified(original, 2020);
            testCase.writeFile(installCopy, "old content");
            testCase.setModified(installCopy, 2024);
            testCase.writeFile(changed, "changed content");
            testCase.setModified(changed, 2022);

            testCase.merge();

            testCase.verifyEqual(string(fileread(testCase.targetPath("custom_options", "preset.mat"))), ...
                "changed content")
        end

        function testIdenticalCopiesAreNotReported(testCase)
            testCase.writeFile(testCase.profilePath("R2024b", "settings", "app.mat"), "same");
            testCase.writeFile(testCase.profilePath("R2026a", "settings", "app.mat"), "same");

            report = testCase.merge();

            testCase.verifyEmpty(report.FileConflicts)
        end
    end

    methods (Test) % Where things go

        function testLocalProjectConfigurationsGoToTheMachineFolder(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));
            testCase.writeFile(testCase.profilePath("R2024b", "projects", "alpha", "task_list.mat"), "tasks");

            testCase.merge();

            localFolder = nansen.localdatadir(fullfile(testCase.UserDataRoot, "default"));
            testCase.verifyTrue(isfile(fullfile(localFolder, "projects", "alpha", "task_list.mat")))
            testCase.verifyFalse(isfolder(testCase.targetPath("projects", "alpha")))
        end

        function testFoldersOfRemovedProjectsAreNotCopied(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));
            testCase.writeFile(testCase.profilePath("R2024b", "projects", "removed", "task_list.mat"), "tasks");

            testCase.merge();

            localFolder = nansen.localdatadir(fullfile(testCase.UserDataRoot, "default"));
            testCase.verifyFalse(isfolder(fullfile(localFolder, "projects", "removed")))
        end

        function testMachineLocalSettingsGoToTheMachineFolder(testCase)
            testCase.writeFile(testCase.profilePath("R2024b", "settings", "task_list.mat"), "tasks");
            testCase.writeFile(testCase.profilePath("R2024b", "settings", "app.mat"), "app");

            testCase.merge();

            localFolder = nansen.localdatadir(fullfile(testCase.UserDataRoot, "default"));
            testCase.verifyTrue(isfile(fullfile(localFolder, "task_list.mat")))
            testCase.verifyFalse(isfile(testCase.targetPath("settings", "task_list.mat")))
            testCase.verifyTrue(isfile(testCase.targetPath("settings", "app.mat")))
        end

        function testProjectFolderInAPreferenceDirectoryIsCopied(testCase)
            insidePath = testCase.profilePath("R2024b", "projects", "alpha");
            testCase.writeFile(fullfile(insidePath, "project.nansen.json"), "{}");
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha", insidePath));

            testCase.merge();

            expectedPath = testCase.targetPath("projects", "alpha");
            testCase.verifyEqual(testCase.readCatalog("default").Path, char(expectedPath))
            testCase.verifyTrue(isfile(fullfile(expectedPath, "project.nansen.json")))
        end

        function testProjectFolderInASetAsideFolderIsFound(testCase)
        %testProjectFolderInASetAsideFolderIsFound The stored path has gone stale
        %
        %   The catalog names the folder at projects/alpha, and a session
        %   has since renamed projects to projects.unmigrated.

            storedPath = testCase.profilePath("R2024b", "projects", "alpha");
            actualPath = testCase.profilePath("R2024b", "projects.unmigrated", "alpha");
            testCase.writeFile(fullfile(actualPath, "project.nansen.json"), "{}");
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha", storedPath), "projects.unmigrated");

            testCase.merge();

            testCase.verifyTrue(isfile(testCase.targetPath("projects", "alpha", "project.nansen.json")))
        end
    end

    methods (Test) % After the merge

        function testMergedFoldersAreRenamed(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));
            testCase.writeFile(testCase.profilePath("R2024b", "settings", "app.mat"), "app");

            testCase.merge();

            testCase.verifyFalse(isfolder(testCase.profilePath("R2024b", "projects")))
            testCase.verifyTrue(isfolder(testCase.profilePath("R2024b", "projects.migrated")))
            testCase.verifyTrue(isfile(testCase.profilePath("R2024b", "settings.migrated", "app.mat")))
        end

        function testSetAsideFolderBecomesMigrated(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"), "projects.unmigrated_2");

            testCase.merge();

            testCase.verifyTrue(isfolder(testCase.profilePath("R2024b", "projects.migrated")))
        end

        function testASecondMergeFindsNothing(testCase)
            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));

            testCase.merge();
            report = testCase.merge();

            testCase.verifyEmpty(report)
            testCase.verifyEqual(numel(testCase.readCatalog("default")), 1)
        end

        function testUnreadableCatalogStaysWhereItIs(testCase)
            testCase.writeFile(testCase.profilePath("R2024b", "projects", "project_catalog.mat"), "not a mat file");
            testCase.writeCatalog("R2026a", "default", testCase.entry("alpha"));

            warningState = warning('off', 'NANSEN:UserSession:UnreadableProjectCatalog');
            testCase.addTeardown(@() warning(warningState));
            testCase.merge();

            testCase.verifyTrue(isfile(testCase.profilePath("R2024b", "projects", "project_catalog.mat")))
            testCase.verifyEqual(string({testCase.readCatalog("default").Name}), "alpha")
        end

        function testFailedMergeLeavesEverythingAsItWas(testCase)
        %testFailedMergeLeavesEverythingAsItWas
        %
        %   A file where the settings folder belongs stops the merge after
        %   the files of custom_options have been considered.

            testCase.writeCatalog("R2024b", "default", testCase.entry("alpha"));
            testCase.writeFile(testCase.profilePath("R2024b", "custom_options", "preset.mat"), "preset");
            testCase.writeFile(testCase.profilePath("R2024b", "settings", "app.mat"), "app");
            testCase.writeFile(testCase.targetPath("settings"), "a file in the way");

            testCase.verifyError(@() testCase.merge(), 'NANSEN:UserSession:MergeUserDataFailed')

            testCase.verifyFalse(isfile(testCase.targetPath("custom_options", "preset.mat")))
            testCase.verifyFalse(isfile(testCase.targetPath("projects", "project_catalog.mat")))
            testCase.verifyTrue(isfile(testCase.profilePath("R2024b", "projects", "project_catalog.mat")))
            testCase.verifyTrue(isfile(testCase.targetPath("settings")))
        end
    end

    methods (Access = private)

        function report = merge(testCase, options)
            arguments
                testCase
                options.Apply (1,1) logical = true
                options.Profiles (1,:) string = string.empty(1, 0)
            end

            report = nansen.internal.user.mergeUserDataFromReleases( ...
                Apply=options.Apply, Profiles=options.Profiles, ...
                PreferenceRoot=testCase.PreferenceRoot, ...
                UserDataRoot=testCase.UserDataRoot, Verbose=false);
        end

        function S = entry(testCase, name, projectPath)
            arguments
                testCase %#ok<INUSA>
                name (1,1) string
                projectPath (1,1) string = testCase.projectFolder(name)
            end

            S = struct('Name', char(name), 'ShortName', char(name), ...
                'Description', 'A project', 'Path', char(projectPath));
        end

        function folderPath = projectFolder(testCase, name)
            folderPath = fullfile(testCase.ProjectRoot, name);
            if ~isfolder(folderPath)
                mkdir(folderPath)
            end
        end

        function filePath = profilePath(testCase, release, folderName, varargin)
        %profilePath Build a path in the default profile of a preference directory
        %
        %   profilePath(release, folderName, "", profile) names the folder
        %   of another profile.

            if numel(varargin) == 2 && varargin{1} == ""
                filePath = fullfile(testCase.PreferenceRoot, release, "Nansen", varargin{2}, folderName);
                return
            end

            filePath = fullfile(testCase.PreferenceRoot, release, "Nansen", "default", folderName, varargin{:});
        end

        function filePath = targetPath(testCase, varargin)
            filePath = fullfile(testCase.UserDataRoot, "default", varargin{:});
        end

        function writeCatalog(testCase, release, profile, projectCatalog, folderName)
            arguments
                testCase
                release (1,1) string
                profile (1,1) string
                projectCatalog
                folderName (1,1) string = "projects"
            end

            folderPath = fullfile(testCase.PreferenceRoot, release, "Nansen", profile, folderName);
            if ~isfolder(folderPath)
                mkdir(folderPath)
            end
            save(fullfile(folderPath, "project_catalog.mat"), 'projectCatalog')
        end

        function writeTargetCatalog(testCase, projectCatalog)
            folderPath = testCase.targetPath("projects");
            mkdir(folderPath)
            save(fullfile(folderPath, "project_catalog.mat"), 'projectCatalog')
        end

        function catalog = readCatalog(testCase, profile)
            S = load(fullfile(testCase.UserDataRoot, profile, "projects", "project_catalog.mat"));
            catalog = S.projectCatalog;
        end

        function writeFile(~, filePath, text)
            folderPath = fileparts(filePath);
            if ~isfolder(folderPath)
                mkdir(folderPath)
            end
            utility.filewrite(char(filePath), char(text))
        end

        function setModified(~, filePath, year)
            millisecondsSinceEpoch = posixtime(datetime(year, 1, 1)) * 1000;
            java.io.File(char(filePath)).setLastModified(millisecondsSinceEpoch);
        end
    end
end
