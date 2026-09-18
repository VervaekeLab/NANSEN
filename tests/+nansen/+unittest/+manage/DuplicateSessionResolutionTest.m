classdef DuplicateSessionResolutionTest < matlab.unittest.TestCase

    methods (Test)
        function testDuplicateTableIsGroupedAndSorted(testCase)
            sessionArray = createMockSessionArray(["B", "A", "B", "C", "A"], ...
                ["b_one", "a_one", "b_two", "c_one", "a_two"]);

            duplicateTable = nansen.manage.buildDuplicateSessionTable(sessionArray);

            testCase.verifyEqual(duplicateTable.SessionID, ["A"; "A"; "B"; "B"])
            testCase.verifyEqual(duplicateTable.DuplicateNumber, [1; 2; 1; 2])
            testCase.verifyEqual(duplicateTable.FolderPath, ...
                ["/tmp/a_one"; "/tmp/a_two"; "/tmp/b_one"; "/tmp/b_two"])
            testCase.verifyEqual(duplicateTable.SessionIndex, [2; 5; 1; 3])
        end

        function testDuplicateMatchingUsesExactSessionIDs(testCase)
            sessionArray = createMockSessionArray(["A", "AA", "A"], ...
                ["a_one", "aa_one", "a_two"]);

            duplicateTable = nansen.manage.buildDuplicateSessionTable(sessionArray);

            testCase.verifyEqual(duplicateTable.SessionID, ["A"; "A"])
            testCase.verifyEqual(duplicateTable.FolderPath, ...
                ["/tmp/a_one"; "/tmp/a_two"])
            testCase.verifyEqual(duplicateTable.SessionIndex, [1; 3])
        end

        function testExcludeAllRemovesEverySharedSessionID(testCase)
            sessionArray = createMockSessionArray(["B", "A", "B", "C", "A"], ...
                ["b_one", "a_one", "b_two", "c_one", "a_two"]);

            remainingSessions = nansen.manage.excludeDuplicateSessions(sessionArray);

            testCase.verifyEqual(string({remainingSessions.sessionID}), "C")
        end

        function testKeepFirstKeepsFirstSessionOfEachID(testCase)
            sessionArray = createMockSessionArray(["B", "A", "B", "C", "A"], ...
                ["b_one", "a_one", "b_two", "c_one", "a_two"]);

            remainingSessions = nansen.manage.excludeDuplicateSessions(...
                sessionArray, KeepFirst=true);

            remainingDataLocations = [remainingSessions.DataLocation];
            testCase.verifyEqual(string({remainingSessions.sessionID}), ["B", "A", "C"])
            testCase.verifyEqual(string({remainingDataLocations.Subfolders}), ...
                ["b_one", "a_one", "c_one"])
        end

        function testKeepFirstKeepsOneOfThreeCopies(testCase)
            sessionArray = createMockSessionArray(["A", "A", "A"], ...
                ["a_one", "a_two", "a_three"]);

            [remainingSessions, excludedSessionTable] = ...
                nansen.manage.excludeDuplicateSessions(sessionArray, KeepFirst=true);

            testCase.verifyEqual(remainingSessions.DataLocation.Subfolders, 'a_one')
            testCase.verifyEqual(excludedSessionTable.FolderPath, ...
                ["/tmp/a_two"; "/tmp/a_three"])
        end

        function testKeepFirstReturnsExcludedSessionTable(testCase)
            sessionArray = createMockSessionArray(["B", "A", "B", "C", "A"], ...
                ["b_one", "a_one", "b_two", "c_one", "a_two"]);

            [~, excludedSessionTable] = nansen.manage.excludeDuplicateSessions(...
                sessionArray, KeepFirst=true);

            testCase.verifyEqual(excludedSessionTable.SessionID, ["A"; "B"])
            testCase.verifyEqual(excludedSessionTable.FolderPath, ...
                ["/tmp/a_two"; "/tmp/b_two"])
            testCase.verifyEqual(excludedSessionTable.SessionIndex, [5; 3])
        end

        function testExcludeAllReturnsEveryDuplicateFolder(testCase)
            sessionArray = createMockSessionArray(["B", "A", "B", "C", "A"], ...
                ["b_one", "a_one", "b_two", "c_one", "a_two"]);

            [~, excludedSessionTable] = nansen.manage.excludeDuplicateSessions(sessionArray);

            testCase.verifyEqual(excludedSessionTable.SessionIndex, [2; 5; 1; 3])
        end

        function testExclusionUsesExactSessionIDs(testCase)
            sessionArray = createMockSessionArray(["A", "AA", "A"], ...
                ["a_one", "aa_one", "a_two"]);

            remainingSessions = nansen.manage.excludeDuplicateSessions(sessionArray);

            testCase.verifyEqual(string({remainingSessions.sessionID}), "AA")
        end

        function testUniqueSessionIDsAreLeftUnchanged(testCase)
            sessionArray = createMockSessionArray(["A", "B", "C"], ...
                ["a_one", "b_one", "c_one"]);

            [remainingSessions, excludedSessionTable] = ...
                nansen.manage.excludeDuplicateSessions(sessionArray, KeepFirst=true);

            testCase.verifyEqual(remainingSessions, sessionArray)
            testCase.verifyEqual(height(excludedSessionTable), 0)
        end

        function testFilesInOneFolderKeepFirstSession(testCase)
            rootPath = testCase.createRootFolderWithFiles(...
                ["A_imaging.tif", "A_behavior.csv", "B_imaging.tif"]);
            sessionArray = createMockSessionArray(["A", "A", "B"], ...
                ["A_imaging.tif", "A_behavior.csv", "B_imaging.tif"], rootPath);

            remainingSessions = nansen.manage.excludeSameFolderDuplicates(sessionArray);

            remainingDataLocations = [remainingSessions.DataLocation];
            testCase.verifyEqual(string({remainingSessions.sessionID}), ["A", "B"])
            testCase.verifyEqual(string({remainingDataLocations.Subfolders}), ...
                ["A_imaging.tif", "B_imaging.tif"])
        end

        function testFilesInDifferentFoldersAreKept(testCase)
            relativeFilePaths = [fullfile("m01", "A_imaging.tif"), ...
                fullfile("m02", "A_imaging.tif")];
            rootPath = testCase.createRootFolderWithFiles(relativeFilePaths);
            sessionArray = createMockSessionArray(["A", "A"], relativeFilePaths, rootPath);

            remainingSessions = nansen.manage.excludeSameFolderDuplicates(sessionArray);

            testCase.verifyEqual(remainingSessions, sessionArray)
        end

        function testOnlySameFolderFilesAreExcluded(testCase)
            relativeFilePaths = [fullfile("m01", "A_imaging.tif"), ...
                fullfile("m02", "A_imaging.tif"), fullfile("m01", "A_behavior.csv")];
            rootPath = testCase.createRootFolderWithFiles(relativeFilePaths);
            sessionArray = createMockSessionArray(["A", "A", "A"], relativeFilePaths, rootPath);

            remainingSessions = nansen.manage.excludeSameFolderDuplicates(sessionArray);

            testCase.verifyEqual(remainingSessions, sessionArray(1:2))
        end

        function testFoldersWithSameSessionIDAreKept(testCase)
            sessionArray = createMockSessionArray(["A", "A"], ["a_one", "a_two"]);

            remainingSessions = nansen.manage.excludeSameFolderDuplicates(sessionArray);

            testCase.verifyEqual(remainingSessions, sessionArray)
        end

        function testSessionObjectsInOneFolderKeepFirst(testCase)
            fileNames = ["A_imaging.tif", "A_behavior.csv", "B_imaging.tif"];
            rootPath = testCase.createRootFolderWithFiles(fileNames);
            sessionArray = createSessionObjectArray(["A", "A", "B"], fileNames, rootPath);

            remainingSessions = nansen.manage.excludeSameFolderDuplicates(sessionArray);

            remainingDataLocations = [remainingSessions.DataLocation];
            testCase.verifyClass(remainingSessions, 'nansen.metadata.type.Session')
            testCase.verifySize(remainingSessions, [2, 1])
            testCase.verifyEqual(string({remainingDataLocations.Subfolders}), ...
                ["A_imaging.tif", "B_imaging.tif"])
        end
    end

    methods (Access = private)
        function rootPath = createRootFolderWithFiles(testCase, relativeFilePaths)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            folderFixture = testCase.applyFixture(TemporaryFolderFixture());
            rootPath = string(folderFixture.Folder);

            for i = 1:numel(relativeFilePaths)
                filePath = fullfile(rootPath, relativeFilePaths(i));
                if ~isfolder(fileparts(filePath))
                    mkdir(fileparts(filePath))
                end
                fileId = fopen(filePath, "w");
                fclose(fileId);
            end
        end
    end
end

function sessionArray = createSessionObjectArray(sessionIDs, subfolders, rootPath)
    arguments
        sessionIDs (:,1) string
        subfolders (:,1) string
        rootPath (1,1) string
    end

    for i = numel(sessionIDs):-1:1
        sessionArray(i, 1) = nansen.metadata.type.Session();
        sessionArray(i).sessionID = char(sessionIDs(i));
        sessionArray(i).DataLocation = struct(...
            'Name', 'Raw', ...
            'RootPath', char(rootPath), ...
            'Subfolders', char(subfolders(i)));
    end
end

function sessionArray = createMockSessionArray(sessionIDs, subfolders, rootPath)
    arguments
        sessionIDs (:,1) string
        subfolders (:,1) string
        rootPath (1,1) string = "/tmp"
    end

    for i = numel(sessionIDs):-1:1
        sessionArray(i).sessionID = char(sessionIDs(i));
        sessionArray(i).DataLocation = struct(...
            'Name', 'Raw', ...
            'RootPath', char(rootPath), ...
            'Subfolders', char(subfolders(i)));
    end
end
