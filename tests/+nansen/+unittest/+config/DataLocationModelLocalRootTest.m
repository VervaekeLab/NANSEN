classdef DataLocationModelLocalRootTest < matlab.unittest.TestCase
    %DataLocationModelLocalRootTest A shared model used from a second computer
    %
    %   A model file records the computer that created it. Another computer
    %   can use different root paths without changing that file.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.DataLocationModelLocalRootTest')

    properties (Constant)
        SOURCE_ROOT = '/source/computer/data'
        LOCAL_ROOT = '/this/computer/data'
    end

    properties
        FilePath char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            % The local settings file belongs to the current project.
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createSharedModel(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.FilePath = fullfile(fixture.Folder, 'datalocation_settings.json');

            testCase.deleteLocalSettings()
            testCase.addTeardown(@() testCase.deleteLocalSettings())

            model = nansen.config.dloc.DataLocationModel(testCase.FilePath);
            item = model.getBlankItem();
            item.Name = 'Processed';
            item.Type = nansen.config.dloc.DataLocationType('processed');
            item.RootPath(1).Key = 'root-1';
            item.RootPath(1).Value = testCase.SOURCE_ROOT;
            item.RootPath(1).DiskName = 'Disk';
            model.insertItem(item)
        end
    end

    methods (Access = private)

        function deleteLocalSettings(~)
            localFolder = nansen.config.project.ProjectManager.getProjectPath('current', 'local');
            filePath = fullfile(localFolder, 'datalocation_local_rootpath_settings.json');
            if isfile(filePath)
                delete(filePath)
            end
        end

        function markFileAsCreatedElsewhere(testCase)
            S = jsondecode(fileread(testCase.FilePath));
            S.Preferences.SourceID = 'another-computer';
            utility.filewrite(testCase.FilePath, jsonencode(S, 'PrettyPrint', true))
        end

        function model = loadModelAndSetRoot(testCase, rootValue)
            model = nansen.config.dloc.DataLocationModel(testCase.FilePath);
            rootPath = model.Data(1).RootPath;
            rootPath(1).Value = rootValue;
            model.modifyDataLocation(model.Data(1).Name, 'RootPath', rootPath);
            model.save()
        end

        function value = rootInSharedFile(testCase)
            S = jsondecode(fileread(testCase.FilePath));
            value = S.Data.RootPath.Value;
        end
    end

    methods (Test)

        function testAnotherComputerLeavesTheSharedRootAlone(testCase)
            testCase.markFileAsCreatedElsewhere()

            testCase.loadModelAndSetRoot(testCase.LOCAL_ROOT);

            testCase.verifyEqual(testCase.rootInSharedFile(), testCase.SOURCE_ROOT)
        end

        function testAnotherComputerReadsItsOwnRootBack(testCase)
            testCase.markFileAsCreatedElsewhere()
            testCase.loadModelAndSetRoot(testCase.LOCAL_ROOT);

            reloaded = nansen.config.dloc.DataLocationModel(testCase.FilePath);

            testCase.verifyEqual(reloaded.Data(1).RootPath(1).Value, testCase.LOCAL_ROOT)
        end

        function testLoadingOnAnotherComputerKeepsTheSharedRoot(testCase)
            testCase.markFileAsCreatedElsewhere()

            nansen.config.dloc.DataLocationModel(testCase.FilePath);

            testCase.verifyEqual(testCase.rootInSharedFile(), testCase.SOURCE_ROOT)
        end

        function testSourceComputerWritesToTheSharedFile(testCase)
            testCase.loadModelAndSetRoot(testCase.LOCAL_ROOT);

            testCase.verifyEqual(testCase.rootInSharedFile(), testCase.LOCAL_ROOT)
        end
    end
end
