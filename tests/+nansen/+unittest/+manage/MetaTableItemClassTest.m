classdef MetaTableItemClassTest < matlab.unittest.TestCase
%MetaTableItemClassTest - Tests that new sessions and subjects need a session or subject class
%
%   nansen.manage.detectNewSessions and nansen.manage.updateSubjectTable
%   create objects of the class that a metatable creates its entries with:
%   its ItemClassName, or its MetaTableClass when ItemClassName is empty.
%   Each test gives them a table whose class is not on the MATLAB path or
%   is not a session or subject class, and checks the error. Both functions
%   check the class before they use a data location model or the current
%   project, so these tests need no project.
%
%   Run tests:
%       runtests('nansen.unittest.manage.MetaTableItemClassTest')

    properties (TestParameter)
        % Class names that cannot create sessions: an empty name, a name
        % that is not a class on the path, and a class that is not a session
        InvalidSessionClass = struct( ...
            "Empty", "", ...
            "NotOnPath", "Session", ...
            "NotSessionClass", "nansen.metadata.type.Subject")
    end

    methods (Test)
        function testDetectNewSessionsRejectsTableClass(testCase, InvalidSessionClass)
            metaTable = nansen.metadata.MetaTable(MetaTableClass=InvalidSessionClass);

            testCase.verifyError(@() nansen.manage.detectNewSessions(metaTable), ...
                "NANSEN:DetectNewSessions:InvalidSessionClass")
        end

        function testDetectNewSessionsChecksItemClassName(testCase)
            metaTable = nansen.metadata.MetaTable( ...
                MetaTableClass="nansen.metadata.type.Session", ...
                ItemClassName="nansen.metadata.type.Subject");

            testCase.verifyError(@() nansen.manage.detectNewSessions(metaTable), ...
                "NANSEN:DetectNewSessions:InvalidSessionClass")
        end

        function testUpdateSubjectTableRejectsClassNotOnPath(testCase)
            % createABO_VisualCoding_CalciumImaging_Project creates a
            % subject table with this class name
            catalog = testCase.createCatalog( ...
                nansen.metadata.MetaTable(MetaTableClass="Subject"));

            testCase.verifyError(@() nansen.manage.updateSubjectTable(catalog), ...
                "NANSEN:UpdateSubjectTable:InvalidSubjectClass")
        end

        function testUpdateSubjectTableChecksItemClassName(testCase)
            catalog = testCase.createCatalog(nansen.metadata.MetaTable( ...
                MetaTableClass="nansen.metadata.type.Subject", ...
                ItemClassName="nansen.metadata.type.Session"));

            testCase.verifyError(@() nansen.manage.updateSubjectTable(catalog), ...
                "NANSEN:UpdateSubjectTable:InvalidSubjectClass")
        end

        function testUpdateSubjectTableChecksGivenClass(testCase)
            catalog = testCase.createCatalog( ...
                nansen.metadata.MetaTable(MetaTableClass="nansen.metadata.type.Subject"));

            testCase.verifyError( ...
                @() nansen.manage.updateSubjectTable(catalog, "nansen.metadata.type.Session"), ...
                "NANSEN:UpdateSubjectTable:InvalidSubjectClass")
        end
    end

    methods (Static, Access = private)
        function catalog = createCatalog(subjectTable)
        %createCatalog - Create a catalog of a session table and the given subject table
            sessionTable = nansen.metadata.MetaTable(MetaTableClass="nansen.metadata.type.Session");
            catalog = nansen.unittest.manage.helper.MetaTableCatalogFake([sessionTable, subjectTable]);
        end
    end
end
