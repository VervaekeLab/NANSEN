classdef UpdateSubjectTableTest < matlab.unittest.TestCase
%UpdateSubjectTableTest - Tests for nansen.manage.updateSubjectTable
%
%   The mock project has a session table whose sessions name several
%   subjects. Each test creates the master subject table from those
%   sessions, removes one subject from it, and checks what
%   updateSubjectTable adds back.
%
%   Run tests:
%       runtests('nansen.unittest.manage.UpdateSubjectTableTest')

    properties
        Catalog
        SessionSubjectIds string
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            testCase.Catalog = nansen.getCurrentProject().MetaTableCatalog;
            sessionTable = testCase.Catalog.getMasterMetaTable('session');
            testCase.SessionSubjectIds = unique(string(sessionTable.entries.subjectID));
            testCase.assumeGreaterThan(numel(testCase.SessionSubjectIds), 1, ...
                'The mock project must have sessions of more than one subject.')
        end
    end

    methods (Test)
        function testAddsEachMissingSubjectOnce(testCase)
            subjectTable = testCase.createSubjectTableWithoutFirstSubject( ...
                'nansen.metadata.type.Subject');

            nansen.manage.updateSubjectTable(testCase.Catalog)

            testCase.verifyEqual(sort(string(subjectTable.entries.SubjectID)), ...
                testCase.SessionSubjectIds)
        end

        function testNewSubjectsHaveClassOfSubjectTable(testCase)
            subjectClassName = 'nansen.unittest.manage.helper.LabeledSubject';
            subjectTable = testCase.createSubjectTableWithoutFirstSubject(subjectClassName);

            nansen.manage.updateSubjectTable(testCase.Catalog)

            testCase.verifyEqual(sort(string(subjectTable.entries.SubjectID)), ...
                testCase.SessionSubjectIds)
            testCase.verifyTrue(ismember('Label', subjectTable.entries.Properties.VariableNames))
            testCase.verifyEqual(subjectTable.MetaTableClass, subjectClassName)
        end
    end

    methods (Access = private)
        function subjectTable = createSubjectTableWithoutFirstSubject(testCase, subjectClassName)
        %createSubjectTableWithoutFirstSubject - Replace the master subject table with one that lacks a subject
            catalog = testCase.Catalog;
            isSubjectTable = catalog.Table.IsMaster & ...
                contains(string(catalog.Table.MetaTableClass), "subject", 'IgnoreCase', true);
            for name = reshape(string(catalog.Table.MetaTableName(isSubjectTable)), 1, [])
                filePath = catalog.getMetaTableFilePath(char(name));
                catalog.removeEntry(char(name))
                if isfile(filePath)
                    nansen.metadata.MetaTableCache.instance().remove(filePath)
                    delete(filePath)
                end
            end

            nansen.config.initializeSubjectTable(catalog, subjectClassName)
            subjectTable = catalog.getMasterMetaTable('subject');
            subjectTable.removeEntries(char(testCase.SessionSubjectIds(1)))
            subjectTable.save()
        end
    end
end
