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

    methods (Access = private)

        function [firstDirectory, secondDirectory] = createDirectoryPair(testCase)
        %createDirectoryPair Create two empty directories in the root folder

            firstDirectory = fullfile(testCase.RootFolder, "first");
            secondDirectory = fullfile(testCase.RootFolder, "second");
            mkdir(firstDirectory)
            mkdir(secondDirectory)
        end

        function createFile(~, folderPath, fileName)
        %createFile Create a small file, and the folder holding it

            if ~isfolder(folderPath); mkdir(folderPath); end
            writelines("content", fullfile(folderPath, fileName))
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
