classdef DetectNewSessionsTest < matlab.unittest.TestCase
%DetectNewSessionsTest - Tests for nansen.manage.detectNewSessions
%
%   The data location of the mock project holds several sessions. Each
%   test creates the master session table with a session class, removes
%   one session from it, and checks what detectNewSessions finds.
%
%   Run tests:
%       runtests('nansen.unittest.manage.DetectNewSessionsTest')

    properties
        Project
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            testCase.Project = nansen.getCurrentProject();
        end
    end

    methods (Test)
        function testDetectsSessionMissingFromTable(testCase)
            [sessionTable, removedSessionId] = testCase.createSessionTableWithoutFirstSession( ...
                @nansen.metadata.type.Session);

            newSessions = nansen.manage.detectNewSessions(sessionTable, 'all');

            testCase.verifyEqual(string({newSessions.sessionID}), removedSessionId)
        end

        function testNewSessionsHaveClassOfSessionTable(testCase)
            sessionTable = testCase.createSessionTableWithoutFirstSession( ...
                @nansen.unittest.manage.helper.LabeledSession);

            newSessions = nansen.manage.detectNewSessions(sessionTable, 'all');

            testCase.verifyClass(newSessions, 'nansen.unittest.manage.helper.LabeledSession')
        end

        function testDetectedSessionsCanBeAddedToTable(testCase)
            % The steps the app takes when the user detects new sessions
            [sessionTable, removedSessionId] = testCase.createSessionTableWithoutFirstSession( ...
                @nansen.unittest.manage.helper.LabeledSession);

            newSessions = nansen.manage.detectNewSessions(sessionTable, 'all');
            newSessionTable = nansen.metadata.MetaTable.new(newSessions);
            testCase.Project.synchronizeMetaTableVariables(newSessionTable);
            sessionTable.addTable(newSessionTable.entries)

            testCase.verifyTrue(ismember(removedSessionId, string(sessionTable.entries.sessionID)))
        end
    end

    methods (Access = private)
        function [sessionTable, removedSessionId] = createSessionTableWithoutFirstSession(testCase, sessionConstructor)
        %createSessionTableWithoutFirstSession - Replace the master session table with one that lacks a session
            catalog = testCase.Project.MetaTableCatalog;
            isSessionTable = catalog.Table.IsMaster & ...
                contains(string(catalog.Table.MetaTableClass), "session", 'IgnoreCase', true);
            for name = reshape(string(catalog.Table.MetaTableName(isSessionTable)), 1, [])
                filePath = catalog.getMetaTableFilePath(char(name));
                catalog.removeEntry(char(name))
                if isfile(filePath)
                    nansen.metadata.MetaTableCache.instance().remove(filePath)
                    delete(filePath)
                end
            end

            % initializeSessionTable registers the table in a catalog it
            % reads from disk, so the catalog is read again here
            nansen.config.initializeSessionTable(testCase.Project.DataLocationModel, ...
                sessionConstructor, SkipInteractiveSteps=true);
            sessionTable = testCase.Project.MetaTableCatalog.getMasterMetaTable('session');
            removedSessionId = string(sessionTable.entries.sessionID{1});
            sessionTable.removeEntries(char(removedSessionId))
            sessionTable.save()
        end
    end
end
