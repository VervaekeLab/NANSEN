classdef RenameStoredIdentifiersTest < matlab.unittest.TestCase
%RenameStoredIdentifiersTest Tests for nansen.config.project.renameStoredIdentifiers
%
%   Builds a small project-like folder with the file kinds the utility
%   scans (the project specification, a MAT catalog, a JSON model and a
%   MAT option set named after a function) and checks the dry run, the
%   applied rewrite, file renaming, backups and idempotence. The rename
%   map is synthetic so the test does not depend on any real module.
%
%   Run tests:
%       runtests('nansen.unittest.config.project.RenameStoredIdentifiersTest')

    properties (Constant, Access = private)
        OldName = "old.pkg.alpha"
        NewName = "new.pkg.alpha"
    end

    methods (Access = private)

        function renameMap = createRenameMap(testCase)
            renameMap = struct( ...
                'Old', {testCase.OldName, testCase.OldName}, ...
                'New', {testCase.NewName, testCase.NewName}, ...
                'Match', {"exact", "prefix"});
        end

        function projectFolder = createProjectFolder(testCase)
        %createProjectFolder Write the fixture files into a temporary folder
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            projectFolder = char(fixture.Folder);

            specification = struct('Properties', struct('Name', 'Fixture'), ...
                'Preferences', struct('DataModule', {{char(testCase.OldName), 'nansen.module.general.core'}}));
            testCase.writeJson(fullfile(projectFolder, 'project.nansen.json'), specification)

            configurationFolder = fullfile(projectFolder, 'configurations');
            mkdir(configurationFolder)

            Data = struct('TaskName', {'run', 'keep', 'longer'}, ...
                'TaskFunction', {char(testCase.OldName + ".sessionmethod.run"), 'core.keep', ...
                                 char(testCase.OldName + "bet.sessionmethod.run")});
            Preferences = struct('Nested', {{char(testCase.OldName + ".Processor")}});
            save(fullfile(configurationFolder, 'PipelineCatalog.mat'), 'Data', 'Preferences')

            model = struct('Items', struct('FileAdapter', {char(testCase.OldName + ".fileadapter.X"), 'other'}));
            testCase.writeJson(fullfile(configurationFolder, 'variables.json'), model)

            optionsFolder = fullfile(configurationFolder, 'custom_options');
            mkdir(optionsFolder)
            DefaultOptionsName = 'Default';
            FunctionName = char(testCase.OldName + ".Processor");
            save(fullfile(optionsFolder, char(testCase.OldName + ".Processor.mat")), 'DefaultOptionsName', 'FunctionName')
        end

        function writeJson(testCase, filePath, value)
            fileId = fopen(filePath, 'w');
            testCase.assertNotEqual(fileId, -1)
            fwrite(fileId, jsonencode(value, 'PrettyPrint', true), 'char');
            fclose(fileId);
        end

        function report = applyRenames(testCase, projectFolder, varargin)
            report = nansen.config.project.renameStoredIdentifiers(projectFolder, ...
                testCase.createRenameMap(), 'Verbose', false, varargin{:});
        end
    end

    methods (Test)

        function testDryRunReportsWithoutModifying(testCase)
            projectFolder = testCase.createProjectFolder();
            before = dir(fullfile(projectFolder, '**', '*'));
            specificationText = fileread(fullfile(projectFolder, 'project.nansen.json'));

            report = testCase.applyRenames(projectFolder);

            testCase.verifyGreaterThanOrEqual(height(report), 5)
            testCase.verifyEqual(fileread(fullfile(projectFolder, 'project.nansen.json')), specificationText)
            after = dir(fullfile(projectFolder, '**', '*'));
            testCase.verifyEqual({after.name}, {before.name})
            testCase.verifyEqual([after.datenum], [before.datenum])
        end

        function testApplyRewritesJsonValues(testCase)
            projectFolder = testCase.createProjectFolder();
            testCase.applyRenames(projectFolder, 'DryRun', false);

            specification = jsondecode(fileread(fullfile(projectFolder, 'project.nansen.json')));
            testCase.verifyEqual(string(specification.Preferences.DataModule{1}), testCase.NewName)
            testCase.verifyEqual(specification.Preferences.DataModule{2}, 'nansen.module.general.core')

            model = jsondecode(fileread(fullfile(projectFolder, 'configurations', 'variables.json')));
            testCase.verifyEqual(string(model.Items(1).FileAdapter), testCase.NewName + ".fileadapter.X")
            testCase.verifyEqual(model.Items(2).FileAdapter, 'other')
        end

        function testApplyRewritesMatValuesAndKeepsTypes(testCase)
            projectFolder = testCase.createProjectFolder();
            testCase.applyRenames(projectFolder, 'DryRun', false);

            S = load(fullfile(projectFolder, 'configurations', 'PipelineCatalog.mat'));
            testCase.verifyClass(S.Data(1).TaskFunction, 'char')
            testCase.verifyEqual(string(S.Data(1).TaskFunction), testCase.NewName + ".sessionmethod.run")
            testCase.verifyEqual(S.Data(2).TaskFunction, 'core.keep')
            testCase.verifyEqual(string(S.Preferences.Nested{1}), testCase.NewName + ".Processor")
        end

        function testPrefixDoesNotMatchLongerIdentifiers(testCase)
            projectFolder = testCase.createProjectFolder();
            testCase.applyRenames(projectFolder, 'DryRun', false);

            S = load(fullfile(projectFolder, 'configurations', 'PipelineCatalog.mat'));
            testCase.verifyEqual(string(S.Data(3).TaskFunction), testCase.OldName + "bet.sessionmethod.run")
        end

        function testOptionSetFilesAreRenamedAndRewritten(testCase)
            projectFolder = testCase.createProjectFolder();
            report = testCase.applyRenames(projectFolder, 'DryRun', false);

            optionsFolder = fullfile(projectFolder, 'configurations', 'custom_options');
            newFile = fullfile(optionsFolder, char(testCase.NewName + ".Processor.mat"));
            testCase.verifyTrue(isfile(newFile))
            testCase.verifyFalse(isfile(fullfile(optionsFolder, char(testCase.OldName + ".Processor.mat"))))
            S = load(newFile);
            testCase.verifyEqual(string(S.FunctionName), testCase.NewName + ".Processor")
            testCase.verifyTrue(any(report.Kind == "filename"))
        end

        function testBackupsAreWrittenUnlessDisabled(testCase)
            projectFolder = testCase.createProjectFolder();
            testCase.applyRenames(projectFolder, 'DryRun', false);
            testCase.verifyTrue(isfile(fullfile(projectFolder, 'project.nansen.json.migration-backup')))

            otherFolder = testCase.createProjectFolder();
            testCase.applyRenames(otherFolder, 'DryRun', false, 'Backup', false);
            testCase.verifyFalse(isfile(fullfile(otherFolder, 'project.nansen.json.migration-backup')))
        end

        function testSecondRunIsIdempotent(testCase)
            projectFolder = testCase.createProjectFolder();
            testCase.applyRenames(projectFolder, 'DryRun', false);
            report = testCase.applyRenames(projectFolder);
            testCase.verifyEmpty(report)
        end

        function testExtraFoldersAreScanned(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            projectFolder = testCase.createProjectFolder();
            extraFolder = char(testCase.applyFixture(TemporaryFolderFixture).Folder);
            FunctionName = char(testCase.OldName + ".Processor");
            save(fullfile(extraFolder, char(testCase.OldName + ".Processor.mat")), 'FunctionName')

            testCase.applyRenames(projectFolder, 'DryRun', false, 'ExtraFolders', string(extraFolder));
            testCase.verifyTrue(isfile(fullfile(extraFolder, char(testCase.NewName + ".Processor.mat"))))
        end

        function testRenameMapCanBeAJsonFile(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            projectFolder = testCase.createProjectFolder();
            mapFolder = char(testCase.applyFixture(TemporaryFolderFixture).Folder);
            mapPath = fullfile(mapFolder, 'renames.json');
            testCase.writeJson(mapPath, struct('Renames', testCase.createRenameMap()))

            report = nansen.config.project.renameStoredIdentifiers(projectFolder, mapPath, 'Verbose', false);
            testCase.verifyGreaterThanOrEqual(height(report), 5)
        end
    end
end
