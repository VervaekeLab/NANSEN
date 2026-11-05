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
    end
end

function sessionArray = createMockSessionArray(sessionIDs, subfolders)
    arguments
        sessionIDs (:,1) string
        subfolders (:,1) string
    end

    for i = numel(sessionIDs):-1:1
        sessionArray(i).sessionID = char(sessionIDs(i));
        sessionArray(i).DataLocation = struct(...
            'Name', 'Raw', ...
            'RootPath', '/tmp', ...
            'Subfolders', char(subfolders(i)));
    end
end
