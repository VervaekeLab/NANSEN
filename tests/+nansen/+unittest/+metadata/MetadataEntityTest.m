classdef MetadataEntityTest < matlab.unittest.TestCase

    properties
        CurrentProject nansen.config.project.Project
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
            testCase.CurrentProject = nansen.getCurrentProject();
        end
    end

    methods (Test)
        function testGetSessionObject(testCase)

            sessionTable = testCase.CurrentProject.MetaTableCatalog.getMetaTable('Session');
            sessionObject = nansen.metadata.type.Session(...
                sessionTable.entries(1,:), ...
                'DataLocationModel', testCase.CurrentProject.DataLocationModel);

            testCase.verifyClass(sessionObject, 'nansen.metadata.type.Session')

            targetFolder = testCase.CurrentProject.getTableVariableFolder();
            targetFolder = fullfile(targetFolder, '+session');
            if ~isfolder(targetFolder); mkdir(targetFolder); end

            sourceFile = dir(fullfile(nansentools.projectdir(), 'tools', 'tests', '**', '*BrainRegion.m'));
            sourceFile = fullfile(sourceFile.folder, sourceFile.name);
            copyfile(sourceFile, targetFolder)

            sessionObject.addDynamicTableVariables()

            sessionObject.updateDynamicVariable('BrainRegion')
            keyboard
        end
        
        function testAddTableVariable(testCase)

        end

        function testUpdateDynamicVariableOfSession(testCase)

        end
    end
end
