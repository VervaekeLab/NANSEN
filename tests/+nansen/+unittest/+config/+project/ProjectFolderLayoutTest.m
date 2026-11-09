classdef ProjectFolderLayoutTest < matlab.unittest.TestCase
%ProjectFolderLayoutTest Tests that path helpers follow the layout that Project defines
%
%   The folder names of a project are defined by constants of
%   nansen.config.project.Project. A helper that spells a name out again
%   can drift away from them.
%
%   Run tests:
%       runtests('nansen.unittest.config.project.ProjectFolderLayoutTest')

    properties (TestParameter)
        MetaTableKeyword = {'MetaTableCatalog', 'MetaTable'}
        ConfigurationKeyword = {'FilePathSettings', 'DataLocationSettings', ...
            'DataLocationCatalog', 'PipelineAssignmentModel'}
    end

    properties
        ProjectFolder (1,1) string
    end

    methods (TestMethodSetup)
        function createProjectFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.ProjectFolder = fixture.Folder;
        end
    end

    methods (Test)

        function testMetaTablePathsFollowTheLayout(testCase, MetaTableKeyword)
            import nansen.config.project.Project

            pathStr = nansen.config.project.ProjectManager.getProjectSubPath( ...
                MetaTableKeyword, char(testCase.ProjectFolder));

            expectedFolder = fullfile(testCase.ProjectFolder, Project.METATABLE_FOLDER_NAME);
            testCase.verifyTrue(startsWith(string(pathStr), expectedFolder))
        end

        function testConfigurationPathsFollowTheLayout(testCase, ConfigurationKeyword)
            import nansen.config.project.Project

            pathStr = nansen.config.project.ProjectManager.getProjectSubPath( ...
                ConfigurationKeyword, char(testCase.ProjectFolder));

            testCase.verifyEqual(string(fileparts(pathStr)), ...
                fullfile(testCase.ProjectFolder, Project.CONFIG_FOLDER_NAME))
        end

        function testMetaTableCatalogFollowsTheLayout(testCase)
            import nansen.config.project.Project

            testCase.applyFixture(nansen.fixture.ProjectFixture)

            currentProjectFolder = nansen.ProjectManager().CurrentProjectPath;
            catalogPath = nansen.metadata.MetaTableCatalog.getFilePath();

            testCase.verifyEqual(string(fileparts(catalogPath)), ...
                string(fullfile(currentProjectFolder, Project.METATABLE_FOLDER_NAME)))
        end
    end
end
