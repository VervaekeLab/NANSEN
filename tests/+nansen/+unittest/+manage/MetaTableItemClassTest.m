classdef MetaTableItemClassTest < matlab.unittest.TestCase
%MetaTableItemClassTest - Tests that new subjects need a subject class
%
%   nansen.manage.updateSubjectTable creates subjects of the class that the
%   subject table creates its entries with: its ItemClassName, or its
%   MetaTableClass when ItemClassName is empty. Each test gives it a
%   session table with a subject that the subject table lacks, and a
%   subject class that is not on the MATLAB path or is not a subject class.
%   The class is checked before a project is used, so these tests need no
%   project. The same check in nansen.manage.detectNewSessions needs
%   session folders and is tested in DetectNewSessionsTest.
%
%   Run tests:
%       runtests('nansen.unittest.manage.MetaTableItemClassTest')

    methods (Test)
        function testUpdateSubjectTableRejectsClassNotOnPath(testCase)
            % createABO_VisualCoding_CalciumImaging_Project creates a
            % subject table with this class name
            catalog = testCase.createCatalog( ...
                testCase.createSubjectTable(MetaTableClass="Subject"));

            testCase.verifyError(@() nansen.manage.updateSubjectTable(catalog), ...
                "NANSEN:UpdateSubjectTable:InvalidSubjectClass")
        end

        function testUpdateSubjectTableChecksItemClassName(testCase)
            catalog = testCase.createCatalog(testCase.createSubjectTable( ...
                MetaTableClass="nansen.metadata.type.Subject", ...
                ItemClassName="nansen.metadata.type.Session"));

            testCase.verifyError(@() nansen.manage.updateSubjectTable(catalog), ...
                "NANSEN:UpdateSubjectTable:InvalidSubjectClass")
        end

        function testUpdateSubjectTableChecksGivenClass(testCase)
            catalog = testCase.createCatalog(testCase.createSubjectTable( ...
                MetaTableClass="nansen.metadata.type.Subject"));

            testCase.verifyError( ...
                @() nansen.manage.updateSubjectTable(catalog, "nansen.metadata.type.Session"), ...
                "NANSEN:UpdateSubjectTable:InvalidSubjectClass")
        end

        function testClassIsNotCheckedWithoutNewSubjects(testCase)
            % A subject table that already has every subject is left alone,
            % whatever its class
            subjectTable = testCase.createSubjectTable(MetaTableClass="Subject", ...
                SubjectIDs="m001");
            catalog = testCase.createCatalog(subjectTable);

            nansen.manage.updateSubjectTable(catalog)

            testCase.verifyEqual(string(subjectTable.entries.SubjectID), "m001")
        end
    end

    methods (Static, Access = private)
        function catalog = createCatalog(subjectTable)
        %createCatalog - Create a catalog of a session table and the given subject table
        %
        %   The session table has one session, of the subject "m001".
            sessionEntries = table({'s001'}, {'m001'}, 'VariableNames', {'sessionID', 'subjectID'});
            sessionTable = nansen.metadata.MetaTable(sessionEntries, ...
                MetaTableClass="nansen.metadata.type.Session", MetaTableIdVarname="sessionID");
            catalog = nansen.unittest.manage.helper.MetaTableCatalogFake([sessionTable, subjectTable]);
        end

        function subjectTable = createSubjectTable(options)
        %createSubjectTable - Create a subject table with the given class names and subjects
        %
        %   The default subject, "m000", is not in the session table. A
        %   MetaTable made from a table without rows has no columns, so the
        %   table always holds a subject.
            arguments
                options.MetaTableClass (1,1) string
                options.ItemClassName (1,1) string = ""
                options.SubjectIDs (1,:) string = "m000"
            end
            subjectEntries = table(cellstr(options.SubjectIDs(:)), 'VariableNames', {'SubjectID'});
            nvPairs = {'MetaTableClass', options.MetaTableClass, 'MetaTableIdVarname', "SubjectID"};
            if options.ItemClassName ~= ""
                nvPairs = [nvPairs, {'ItemClassName', options.ItemClassName}];
            end
            subjectTable = nansen.metadata.MetaTable(subjectEntries, nvPairs{:});
        end
    end
end
