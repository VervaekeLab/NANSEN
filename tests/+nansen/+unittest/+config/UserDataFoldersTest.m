classdef UserDataFoldersTest < matlab.unittest.TestCase
% UserDataFoldersTest - Tests for the helpers that move NANSEN user data
%
%   Covers nansen.internal.system.moveFolderContents and the functions in
%   nansen.internal.user that check, move and migrate the folders of a user
%   data directory. Every test works in its own temporary folder, and no
%   test starts a user session, so the real user data directory and the
%   preference directory are not touched.
%
%   Run tests:
%       runtests('nansen.unittest.config.UserDataFoldersTest')

    properties (Constant)
        FOLDER_NAMES = ["projects", "settings", "custom_options", "local"]
    end

    properties
        % RootFolder - Temporary folder holding the directories of a test
        RootFolder (1,1) string
    end

    methods (TestMethodSetup)
        function createRootFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.RootFolder = fixture.Folder;
        end
    end

    methods (Test) % moveFolderContents

        function testMoveFolderContentsReturnsMovedNames(testCase)
        % Every entry moves, hidden ones included, and is reported

            sourceFolder = fullfile(testCase.RootFolder, "source");
            targetFolder = fullfile(testCase.RootFolder, "target");
            testCase.createFile(sourceFolder, "a.txt")
            testCase.createFile(sourceFolder, ".hidden")
            testCase.createFile(fullfile(sourceFolder, "sub"), "b.txt")

            movedNames = nansen.internal.system.moveFolderContents(sourceFolder, targetFolder);

            testCase.verifyEqual(sort(movedNames), sort([".hidden", "a.txt", "sub"]))
            testCase.verifyTrue(isfile(fullfile(targetFolder, "sub", "b.txt")))
            testCase.verifyTrue(isfile(fullfile(targetFolder, ".hidden")))
            testCase.verifyEmpty(testCase.listEntries(sourceFolder))
        end

        function testMoveFolderContentsMovesOnlyNamedEntries(testCase)
            sourceFolder = fullfile(testCase.RootFolder, "source");
            targetFolder = fullfile(testCase.RootFolder, "target");
            testCase.createFile(sourceFolder, "a.txt")
            testCase.createFile(sourceFolder, "b.txt")

            movedNames = nansen.internal.system.moveFolderContents( ...
                sourceFolder, targetFolder, EntryNames="a.txt");

            testCase.verifyEqual(movedNames, "a.txt")
            testCase.verifyTrue(isfile(fullfile(targetFolder, "a.txt")))
            testCase.verifyTrue(isfile(fullfile(sourceFolder, "b.txt")))
        end

        function testUndoMovesBackOnlyWhatWasMoved(testCase)
        % Undoing a move must not carry along what the target held before

            sourceFolder = fullfile(testCase.RootFolder, "source");
            targetFolder = fullfile(testCase.RootFolder, "target");
            testCase.createFile(sourceFolder, "mine.txt")
            testCase.createFile(targetFolder, "theirs.txt")

            movedNames = nansen.internal.system.moveFolderContents(sourceFolder, targetFolder);
            nansen.internal.system.moveFolderContents( ...
                targetFolder, sourceFolder, EntryNames=movedNames);

            testCase.verifyEqual(testCase.listEntries(sourceFolder), "mine.txt")
            testCase.verifyEqual(testCase.listEntries(targetFolder), "theirs.txt")
        end

        function testCollisionIsReportedBeforeAnythingMoves(testCase)
            sourceFolder = fullfile(testCase.RootFolder, "source");
            targetFolder = fullfile(testCase.RootFolder, "target");
            testCase.createFile(sourceFolder, "a.txt")
            testCase.createFile(sourceFolder, "b.txt")
            testCase.createFile(targetFolder, "b.txt")

            testCase.verifyError( ...
                @() nansen.internal.system.moveFolderContents(sourceFolder, targetFolder), ...
                'NANSEN:MoveFolder:TargetExists')

            testCase.verifyEqual(testCase.listEntries(sourceFolder), ["a.txt", "b.txt"])
        end

        function testFailedMoveIsUndone(testCase)
        % The second entry does not exist, so its move fails after the first

            sourceFolder = fullfile(testCase.RootFolder, "source");
            targetFolder = fullfile(testCase.RootFolder, "target");
            testCase.createFile(sourceFolder, "a.txt")

            testCase.verifyError( ...
                @() nansen.internal.system.moveFolderContents(sourceFolder, ...
                    targetFolder, EntryNames=["a.txt", "missing.txt"]), ...
                'NANSEN:MoveFolder:MoveFailed')

            testCase.verifyTrue(isfile(fullfile(sourceFolder, "a.txt")))
            testCase.verifyFalse(isfolder(targetFolder), ...
                'The target folder created by the failed move must be removed.')
        end
    end

    methods (Test) % moveUserDataFolders

        function testOnlyTheNamedFoldersMove(testCase)
            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat")
            testCase.createFile(fullfile(sourceDirectory, "settings"), "app.mat")
            testCase.createFile(sourceDirectory, "notes.txt")
            testCase.createFile(fullfile(sourceDirectory, "other"), "file.txt")

            nansen.internal.user.moveUserDataFolders( ...
                sourceDirectory, targetDirectory, testCase.FOLDER_NAMES)

            testCase.verifyTrue(isfile(fullfile(targetDirectory, "projects", "project_catalog.mat")))
            testCase.verifyTrue(isfile(fullfile(targetDirectory, "settings", "app.mat")))
            testCase.verifyEqual(sort(testCase.listEntries(sourceDirectory)), ["notes.txt", "other"])
            testCase.verifyEqual(sort(testCase.listEntries(targetDirectory)), ["projects", "settings"])
        end

        function testCollisionInAnyFolderMovesNothing(testCase)
        % A release whose prefdir has an empty projects folder, and a
        % settings file that another release already moved to the target.
        % The catalog in the target must stay where it is.

            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            mkdir(fullfile(sourceDirectory, "projects"))
            testCase.createFile(fullfile(sourceDirectory, "settings"), "app.mat")
            testCase.createFile(fullfile(targetDirectory, "projects"), "project_catalog.mat")
            testCase.createFile(fullfile(targetDirectory, "settings"), "app.mat")

            testCase.verifyError( ...
                @() nansen.internal.user.moveUserDataFolders( ...
                    sourceDirectory, targetDirectory, testCase.FOLDER_NAMES), ...
                'NANSEN:MoveFolder:TargetExists')

            testCase.verifyTrue(isfile(fullfile(targetDirectory, "projects", "project_catalog.mat")))
            testCase.verifyTrue(isfolder(fullfile(sourceDirectory, "projects")))
            testCase.verifyEmpty(testCase.listEntries(fullfile(sourceDirectory, "projects")))
            testCase.verifyTrue(isfile(fullfile(sourceDirectory, "settings", "app.mat")))
        end

        function testFailedMoveRestoresExactlyWhatMoved(testCase)
        % projects moves, then settings fails. Undoing projects must not
        % carry along the entry that the target's projects folder held.

            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat")
            testCase.createFile(fullfile(sourceDirectory, "settings"), "app.mat")
            testCase.createFile(fullfile(targetDirectory, "projects"), "unrelated.txt")

            readOnlyFolder = fullfile(targetDirectory, "settings");
            mkdir(readOnlyFolder)
            testCase.makeReadOnly(readOnlyFolder)

            testCase.verifyError( ...
                @() nansen.internal.user.moveUserDataFolders( ...
                    sourceDirectory, targetDirectory, testCase.FOLDER_NAMES), ...
                'NANSEN:UserSession:MoveUserDataFailed')

            testCase.verifyEqual(testCase.listEntries(fullfile(sourceDirectory, "projects")), ...
                "project_catalog.mat")
            testCase.verifyEqual(testCase.listEntries(fullfile(targetDirectory, "projects")), ...
                "unrelated.txt")
            testCase.verifyTrue(isfile(fullfile(sourceDirectory, "settings", "app.mat")))
        end

        function testFailureToRemoveSourceFolderIsUndone(testCase)
        % The contents of projects move, but the emptied folder can not be
        % removed. The move must be undone rather than left half done.

            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat")
            testCase.makeReadOnly(sourceDirectory)

            testCase.verifyError( ...
                @() nansen.internal.user.moveUserDataFolders( ...
                    sourceDirectory, targetDirectory, testCase.FOLDER_NAMES), ...
                'NANSEN:UserSession:MoveUserDataFailed')

            testCase.verifyTrue(isfile(fullfile(sourceDirectory, "projects", "project_catalog.mat")))
            testCase.verifyEmpty(testCase.listEntries(targetDirectory))
        end
    end

    methods (Test) % validateUserDataTarget

        function testTargetInsideCurrentIsRefused(testCase)
        % Choosing <current>/local would move local into local/local

            currentDirectory = fullfile(testCase.RootFolder, "current");
            mkdir(currentDirectory)

            testCase.verifyError( ...
                @() nansen.internal.user.validateUserDataTarget( ...
                    fullfile(currentDirectory, "local"), currentDirectory, testCase.FOLDER_NAMES), ...
                'NANSEN:UserSession:NestedUserDataDirectory')
        end

        function testTargetContainingCurrentIsRefused(testCase)
            currentDirectory = fullfile(testCase.RootFolder, "a", "b");
            mkdir(currentDirectory)

            testCase.verifyError( ...
                @() nansen.internal.user.validateUserDataTarget( ...
                    fullfile(testCase.RootFolder, "a"), currentDirectory, testCase.FOLDER_NAMES), ...
                'NANSEN:UserSession:NestedUserDataDirectory')
        end

        function testTargetWithUserDataFolderIsRefused(testCase)
        % A folder such as a Dropbox root can hold a settings folder of its own

            [currentDirectory, targetDirectory] = testCase.createDirectoryPair();
            mkdir(fullfile(targetDirectory, "settings"))

            try
                nansen.internal.user.validateUserDataTarget( ...
                    targetDirectory, currentDirectory, testCase.FOLDER_NAMES)
                testCase.verifyFail('A directory with a settings folder must be refused.')
            catch ME
                testCase.verifyEqual(ME.identifier, 'NANSEN:UserSession:UserDataDirectoryInUse')
                testCase.verifySubstring(ME.message, '"settings"')
            end
        end

        function testTargetWithUserDataFileIsRefused(testCase)
            [currentDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(targetDirectory, "local")

            testCase.verifyError( ...
                @() nansen.internal.user.validateUserDataTarget( ...
                    targetDirectory, currentDirectory, testCase.FOLDER_NAMES), ...
                'NANSEN:UserSession:UserDataDirectoryInUse')
        end

        function testTargetWithOtherContentIsAccepted(testCase)
        % Files that are not user data folders stay where they are

            [currentDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(targetDirectory, "notes.txt")
            testCase.createFile(fullfile(targetDirectory, "projects.unmigrated"), "x.txt")

            testCase.verifyWarningFree(@() nansen.internal.user.validateUserDataTarget( ...
                targetDirectory, currentDirectory, testCase.FOLDER_NAMES))
        end

        function testSiblingTargetIsAccepted(testCase)
        % "data2" starts with the characters of "data" but is not inside it

            currentDirectory = fullfile(testCase.RootFolder, "data");
            mkdir(currentDirectory)

            testCase.verifyWarningFree(@() nansen.internal.user.validateUserDataTarget( ...
                fullfile(testCase.RootFolder, "data2"), currentDirectory, testCase.FOLDER_NAMES))
        end
    end

    methods (Test) % migrateUserDataFolders

        function testMigrationMovesFoldersTheTargetLacks(testCase)
            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat")
            testCase.createFile(fullfile(sourceDirectory, "settings"), "app.mat")

            result = nansen.internal.user.migrateUserDataFolders( ...
                sourceDirectory, targetDirectory, testCase.FOLDER_NAMES);

            testCase.verifyEqual(result.MovedFolderNames, ["projects", "settings"])
            testCase.verifyEmpty(result.RenamedFolderNames)
            testCase.verifyTrue(isfile(fullfile(targetDirectory, "projects", "project_catalog.mat")))
            testCase.verifyEmpty(testCase.listEntries(sourceDirectory))
        end

        function testMigrationKeepsDataTheTargetHolds(testCase)
        % Another release moved its catalog and settings first. Those are
        % used, and this release's copies are renamed, not merged.

            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat", "this release")
            testCase.createFile(fullfile(sourceDirectory, "settings"), "app.mat", "this release")
            testCase.createFile(fullfile(sourceDirectory, "custom_options"), "preset.mat")
            testCase.createFile(fullfile(targetDirectory, "projects"), "project_catalog.mat", "other release")
            testCase.createFile(fullfile(targetDirectory, "settings"), "app.mat", "other release")

            result = nansen.internal.user.migrateUserDataFolders( ...
                sourceDirectory, targetDirectory, testCase.FOLDER_NAMES);

            testCase.verifyEqual(result.MovedFolderNames, "custom_options")
            testCase.verifyEqual(result.RenamedFolderNames, ["projects", "settings"])
            testCase.verifyEqual(result.RenamedFolderPaths, ...
                fullfile(sourceDirectory, ["projects.unmigrated", "settings.unmigrated"]))

            testCase.verifyEqual(testCase.readFile(targetDirectory, "projects", "project_catalog.mat"), ...
                "other release")
            testCase.verifyEqual(testCase.readFile(sourceDirectory, "projects.unmigrated", ...
                "project_catalog.mat"), "this release")
            testCase.verifyTrue(isfile(fullfile(targetDirectory, "custom_options", "preset.mat")))
            testCase.verifyEqual(testCase.listEntries(sourceDirectory), ...
                ["projects.unmigrated", "settings.unmigrated"])
        end

        function testMigrationRemovesEmptyCopyTheTargetHolds(testCase)
        % An empty projects folder holds nothing to keep apart

            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            mkdir(fullfile(sourceDirectory, "projects"))
            testCase.createFile(fullfile(targetDirectory, "projects"), "project_catalog.mat")

            result = nansen.internal.user.migrateUserDataFolders( ...
                sourceDirectory, targetDirectory, testCase.FOLDER_NAMES);

            testCase.verifyEmpty(result.MovedFolderNames)
            testCase.verifyEmpty(result.RenamedFolderNames)
            testCase.verifyEmpty(testCase.listEntries(sourceDirectory))
            testCase.verifyTrue(isfile(fullfile(targetDirectory, "projects", "project_catalog.mat")))
        end

        function testMigrationIsNotRepeated(testCase)
        % After a migration that renamed folders, a second one finds
        % nothing to do, so it does not run again at every startup.

            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat")
            testCase.createFile(fullfile(targetDirectory, "projects"), "project_catalog.mat")
            nansen.internal.user.migrateUserDataFolders( ...
                sourceDirectory, targetDirectory, testCase.FOLDER_NAMES);

            legacyFolders = fullfile(sourceDirectory, testCase.FOLDER_NAMES);
            testCase.verifyFalse(any(isfolder(legacyFolders)))
        end

        function testRenameChoosesUnusedName(testCase)
            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat")
            testCase.createFile(fullfile(sourceDirectory, "projects.unmigrated"), "earlier.mat")
            testCase.createFile(fullfile(targetDirectory, "projects"), "project_catalog.mat")

            result = nansen.internal.user.migrateUserDataFolders( ...
                sourceDirectory, targetDirectory, testCase.FOLDER_NAMES);

            testCase.verifyEqual(result.RenamedFolderPaths, ...
                fullfile(sourceDirectory, "projects.unmigrated_2"))
            testCase.verifyTrue(isfile(fullfile(sourceDirectory, "projects.unmigrated", "earlier.mat")))
        end

        function testFailedMigrationRestoresRenamedFolders(testCase)
        % projects is renamed, then settings fails to move. The rename
        % must be undone, so the preference directory is as it was.

            [sourceDirectory, targetDirectory] = testCase.createDirectoryPair();
            testCase.createFile(fullfile(sourceDirectory, "projects"), "project_catalog.mat")
            testCase.createFile(fullfile(sourceDirectory, "settings"), "app.mat")
            testCase.createFile(fullfile(targetDirectory, "projects"), "project_catalog.mat")

            readOnlyFolder = fullfile(targetDirectory, "settings");
            mkdir(readOnlyFolder)
            testCase.makeReadOnly(readOnlyFolder)

            testCase.verifyError( ...
                @() nansen.internal.user.migrateUserDataFolders( ...
                    sourceDirectory, targetDirectory, testCase.FOLDER_NAMES), ...
                'NANSEN:UserSession:MoveUserDataFailed')

            testCase.verifyEqual(testCase.listEntries(sourceDirectory), ["projects", "settings"])
            testCase.verifyTrue(isfile(fullfile(sourceDirectory, "projects", "project_catalog.mat")))
            testCase.verifyTrue(isfile(fullfile(sourceDirectory, "settings", "app.mat")))
        end
    end

    methods (Test) % moveMachineLocalSettings

        function testMachineLocalFilesMoveToLocalFolder(testCase)
        % TaskList and WatchFolderCatalog resolve to the machine folder

            userDataDirectory = fullfile(testCase.RootFolder, "userdata");
            settingsFolder = fullfile(userDataDirectory, "settings");
            testCase.createFile(settingsFolder, "task_list.mat")
            testCase.createFile(settingsFolder, "watch_folder_catalog.mat")
            testCase.createFile(settingsFolder, "app.mat")

            nansen.internal.user.moveMachineLocalSettings(userDataDirectory)

            localFolder = nansen.localdatadir(userDataDirectory);
            testCase.verifyTrue(isfile(fullfile(localFolder, "task_list.mat")))
            testCase.verifyTrue(isfile(fullfile(localFolder, "watch_folder_catalog.mat")))
            testCase.verifyEqual(testCase.listEntries(settingsFolder), "app.mat")
        end

        function testNothingToMoveCreatesNoMachineFolder(testCase)
        % It runs at every startup, so with nothing to move it must do nothing

            userDataDirectory = fullfile(testCase.RootFolder, "userdata");
            testCase.createFile(fullfile(userDataDirectory, "settings"), "app.mat")

            nansen.internal.user.moveMachineLocalSettings(userDataDirectory)

            testCase.verifyEqual(testCase.listEntries(userDataDirectory), "settings")
        end

        function testMachineLocalFileIsNotOverwritten(testCase)
            userDataDirectory = fullfile(testCase.RootFolder, "userdata");
            localFolder = nansen.localdatadir(userDataDirectory);
            testCase.createFile(fullfile(userDataDirectory, "settings"), "task_list.mat", "settings copy")
            testCase.createFile(localFolder, "task_list.mat", "machine copy")

            testCase.verifyWarning( ...
                @() nansen.internal.user.moveMachineLocalSettings(userDataDirectory), ...
                'NANSEN:UserSession:MachineLocalFileConflict')

            testCase.verifyEqual(testCase.readFile(localFolder, "task_list.mat"), "machine copy")
            testCase.verifyEqual(testCase.readFile(userDataDirectory, "settings", "task_list.mat"), ...
                "settings copy")
        end
    end

    methods (Test) % UserDataRedirect

        function testRedirectNamesWrittenDirectory(testCase)
            import nansen.internal.user.UserDataRedirect

            [defaultDirectory, userDataDirectory] = testCase.createDirectoryPair();

            UserDataRedirect.write(defaultDirectory, userDataDirectory)

            testCase.verifyEqual(UserDataRedirect.read(defaultDirectory), userDataDirectory)
            testCase.verifyEqual(UserDataRedirect.follow(defaultDirectory), userDataDirectory)
        end

        function testRedirectCreatesMissingDefaultDirectory(testCase)
            import nansen.internal.user.UserDataRedirect

            defaultDirectory = fullfile(testCase.RootFolder, "profiles", "default");

            UserDataRedirect.write(defaultDirectory, testCase.RootFolder)

            testCase.verifyTrue(isfile(UserDataRedirect.getFilePath(defaultDirectory)))
        end

        function testRedirectKeepsNonAsciiPath(testCase)
        % Folder names can hold letters such as æ, ø and å
            import nansen.internal.user.UserDataRedirect

            defaultDirectory = fullfile(testCase.RootFolder, "default");
            userDataDirectory = fullfile(testCase.RootFolder, "Blåbær Ørret");
            mkdir(userDataDirectory)

            UserDataRedirect.write(defaultDirectory, userDataDirectory)

            testCase.verifyEqual(UserDataRedirect.follow(defaultDirectory), userDataDirectory)
        end

        function testRedirectToMissingFolderIsNotFollowed(testCase)
        % For example a directory on a drive that is not connected
            import nansen.internal.user.UserDataRedirect

            defaultDirectory = fullfile(testCase.RootFolder, "default");
            missingDirectory = fullfile(testCase.RootFolder, "missing");

            UserDataRedirect.write(defaultDirectory, missingDirectory)

            testCase.verifyEqual(UserDataRedirect.read(defaultDirectory), missingDirectory)
            testCase.verifyEqual(UserDataRedirect.follow(defaultDirectory), "")
        end

        function testRedirectToRelativePathIsNotFollowed(testCase)
        % A relative path would resolve against MATLAB's current folder
            import nansen.internal.user.UserDataRedirect
            import matlab.unittest.fixtures.CurrentFolderFixture

            defaultDirectory = fullfile(testCase.RootFolder, "default");
            mkdir(fullfile(testCase.RootFolder, "relative"))
            testCase.applyFixture(CurrentFolderFixture(testCase.RootFolder));

            UserDataRedirect.write(defaultDirectory, "relative")

            testCase.verifyEqual(UserDataRedirect.follow(defaultDirectory), "")
        end

        function testRemovedRedirectIsNotRead(testCase)
            import nansen.internal.user.UserDataRedirect

            [defaultDirectory, userDataDirectory] = testCase.createDirectoryPair();
            UserDataRedirect.write(defaultDirectory, userDataDirectory)

            UserDataRedirect.remove(defaultDirectory)

            testCase.verifyFalse(isfile(UserDataRedirect.getFilePath(defaultDirectory)))
            testCase.verifyEqual(UserDataRedirect.read(defaultDirectory), "")
            testCase.verifyWarningFree(@() UserDataRedirect.remove(defaultDirectory))
        end
    end

    methods (Test) % getMachineIdentifier

        function testMachineIdentifierIsFilenameSafe(testCase)
        % It names a folder, local/<identifier>, on every platform

            machineIdentifier = nansen.internal.system.getMachineIdentifier();

            testCase.verifyClass(machineIdentifier, 'string')
            testCase.verifyEqual(strlength(machineIdentifier), 32)
            testCase.verifyTrue(all(isstrprop(char(machineIdentifier), 'xdigit')))
        end

        function testMachineIdentifierOnMacUsesHardwareUuid(testCase)
        % The en0 address that getComputerName hashes can change with the
        % Wi-Fi network. The hardware UUID does not.

            testCase.assumeTrue(ismac, 'The hardware UUID is read on macOS only.')

            [status, output] = system('/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice');
            testCase.assumeEqual(status, 0)
            platformUuid = extractBetween(string(output), '"IOPlatformUUID" = "', '"');
            testCase.assumeNotEmpty(platformUuid)

            engine = java.security.MessageDigest.getInstance('MD5');
            engine.update(typecast(uint16(char(platformUuid(1))), 'uint8'));
            expected = string(sprintf('%.2x', double(typecast(engine.digest, 'uint8'))));

            testCase.verifyEqual(nansen.internal.system.getMachineIdentifier(), expected)
        end

        function testMachineIdentifierElsewhereUsesComputerName(testCase)
            testCase.assumeFalse(ismac, 'macOS uses the hardware UUID.')

            testCase.verifyEqual(nansen.internal.system.getMachineIdentifier(), ...
                string(utility.system.getComputerName(true)))
        end
    end

    methods (Access = private)

        function [firstDirectory, secondDirectory] = createDirectoryPair(testCase)
        %createDirectoryPair Create two empty directories in the root folder

            firstDirectory = fullfile(testCase.RootFolder, "first");
            secondDirectory = fullfile(testCase.RootFolder, "second");
            mkdir(firstDirectory)
            mkdir(secondDirectory)
        end

        function createFile(~, folderPath, fileName, content)
        %createFile Create a one line text file, and the folder holding it

            arguments
                ~
                folderPath (1,1) string
                fileName (1,1) string
                content (1,1) string = "content"
            end

            if ~isfolder(folderPath); mkdir(folderPath); end
            writelines(content, fullfile(folderPath, fileName))
        end

        function content = readFile(~, pathParts)
        %readFile Read the first line of a file made by createFile

            arguments
                ~
            end

            arguments (Repeating)
                pathParts (1,1) string
            end

            content = readlines(fullfile(pathParts{:}), "EmptyLineRule", "skip");
            content = content(1);
        end

        function entryNames = listEntries(~, folderPath)
        %listEntries List the entry names of a folder, hidden ones included

            listing = dir(folderPath);
            entryNames = setdiff(string({listing.name}), [".", ".."]);
            entryNames = reshape(entryNames, 1, []);
        end

        function makeReadOnly(testCase, folderPath)
        %makeReadOnly Remove write permission from a folder for this test
        %
        %   Write protection does not apply to a superuser, in which case
        %   the failure the test needs can not be produced and the test is
        %   filtered.

            fileattrib(folderPath, '-w');
            testCase.addTeardown(@() fileattrib(folderPath, '+w'))

            probePath = fullfile(folderPath, "write_probe.txt");
            fileId = fopen(probePath, 'w');
            if fileId ~= -1
                fclose(fileId);
                delete(probePath)
                testCase.assumeFail('Write protection has no effect for this user.')
            end
        end
    end
end
