classdef LocalRootPathManagerTest < matlab.unittest.TestCase
    %LocalRootPathManagerTest Keeping root paths local to a computer
    %
    %   A computer other than the one that created a project keeps its own
    %   root paths in a local settings file and applies them when loading.
    %   When saving, the root paths of the source computer are put back so
    %   that the shared file does not change.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.LocalRootPathManagerTest')

    properties (Constant)
        SETTINGS_FILE_NAME = 'datalocation_local_rootpath_settings.json'
        SOURCE_ROOT = '/source/computer/data'
        LOCAL_ROOT = '/this/computer/data'
    end

    properties
        Folder char
        Manager
    end

    methods (TestMethodSetup)
        function createManager(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;
            testCase.Manager = nansen.config.dloc.LocalRootPathManager(testCase.Folder);
        end
    end

    methods (Static, Access = private)

        function S = makeRootPath(key, value, diskName, diskType)
            S = struct('Key', key, 'Value', value, 'DiskName', diskName, 'DiskType', diskType);
        end

        function preferences = preferencesOfThisComputer()
            preferences = struct('SourceID', utility.system.getComputerName(true));
        end

        function preferences = preferencesOfAnotherComputer()
            preferences = struct('SourceID', 'another-computer');
        end
    end

    methods (Access = private)

        function data = makeData(testCase, rootValue)
            data = struct('Uuid', 'location-1', 'RootPath', ...
                testCase.makeRootPath('root-1', rootValue, 'Disk', 'External'));
        end

        function writeLocalSettings(testCase, rootPathList)
            text = jsonencode(struct('RootPathListLocal', rootPathList), 'PrettyPrint', true);
            utility.filewrite(fullfile(testCase.Folder, testCase.SETTINGS_FILE_NAME), text)
        end
    end

    methods (Test)

        function testImportAppliesLocalRootsOnAnotherComputer(testCase)
            testCase.writeLocalSettings(testCase.makeData(testCase.LOCAL_ROOT));

            data = testCase.Manager.importLocalRootPaths( ...
                testCase.makeData(testCase.SOURCE_ROOT), testCase.preferencesOfAnotherComputer());

            testCase.verifyEqual(data.RootPath.Value, testCase.LOCAL_ROOT)
        end

        function testImportIgnoresLocalRootsOnTheSourceComputer(testCase)
            testCase.writeLocalSettings(testCase.makeData(testCase.LOCAL_ROOT));

            data = testCase.Manager.importLocalRootPaths( ...
                testCase.makeData(testCase.SOURCE_ROOT), testCase.preferencesOfThisComputer());

            testCase.verifyEqual(data.RootPath.Value, testCase.SOURCE_ROOT)
        end

        function testExportRestoresOriginalsAndStoresLocalRoots(testCase)
            preferences = testCase.preferencesOfAnotherComputer();
            testCase.Manager.importLocalRootPaths(testCase.makeData(testCase.SOURCE_ROOT), preferences);

            data = testCase.Manager.exportLocalRootPaths( ...
                testCase.makeData(testCase.LOCAL_ROOT), preferences);

            testCase.verifyEqual(data.RootPath.Value, testCase.SOURCE_ROOT)
            stored = jsondecode(fileread(fullfile(testCase.Folder, testCase.SETTINGS_FILE_NAME)));
            testCase.verifyEqual(stored.RootPathListLocal.RootPath.Value, testCase.LOCAL_ROOT)
        end

        function testExportChangesNothingOnTheSourceComputer(testCase)
            preferences = testCase.preferencesOfThisComputer();
            testCase.Manager.importLocalRootPaths(testCase.makeData(testCase.SOURCE_ROOT), preferences);

            data = testCase.Manager.exportLocalRootPaths( ...
                testCase.makeData(testCase.LOCAL_ROOT), preferences);

            testCase.verifyEqual(data.RootPath.Value, testCase.LOCAL_ROOT)
            testCase.verifyFalse(isfile(fullfile(testCase.Folder, testCase.SETTINGS_FILE_NAME)))
        end

        function testDataLocationWithoutRootsIsSkipped(testCase)
            % A settings file stores an empty root path list as [], which
            % has no fields to read.
            settings = struct('Uuid', {'location-without-roots', 'location-1'}, ...
                'RootPath', {[], testCase.makeRootPath('root-1', testCase.LOCAL_ROOT, 'Disk', 'External')});
            testCase.writeLocalSettings(settings);

            data = struct('Uuid', {'location-without-roots', 'location-1'}, ...
                'RootPath', {[], testCase.makeRootPath('root-1', testCase.SOURCE_ROOT, 'Disk', 'External')});
            data = testCase.Manager.importLocalRootPaths(data, testCase.preferencesOfAnotherComputer());

            testCase.verifyEmpty(data(1).RootPath)
            testCase.verifyEqual(data(2).RootPath.Value, testCase.LOCAL_ROOT)
        end

        function testRootUnknownToTheReferenceIsKept(testCase)
            settings = struct('Uuid', 'location-1', 'RootPath', ...
                testCase.makeRootPath('other-root', testCase.LOCAL_ROOT, 'Disk', 'External'));
            testCase.writeLocalSettings(settings);

            data = testCase.Manager.importLocalRootPaths( ...
                testCase.makeData(testCase.SOURCE_ROOT), testCase.preferencesOfAnotherComputer());

            testCase.verifyEqual(data.RootPath.Value, testCase.SOURCE_ROOT)
        end

        function testDiskNameIsCopiedOnlyForLocalDisks(testCase)
            settings = struct('Uuid', {'location-1', 'location-2'}, 'RootPath', { ...
                testCase.makeRootPath('root-1', testCase.LOCAL_ROOT, 'LocalName', 'Local'), ...
                testCase.makeRootPath('root-2', testCase.LOCAL_ROOT, 'LocalName', 'External')});
            testCase.writeLocalSettings(settings);

            data = struct('Uuid', {'location-1', 'location-2'}, 'RootPath', { ...
                testCase.makeRootPath('root-1', testCase.SOURCE_ROOT, 'SharedName', 'Local'), ...
                testCase.makeRootPath('root-2', testCase.SOURCE_ROOT, 'SharedName', 'External')});
            data = testCase.Manager.importLocalRootPaths(data, testCase.preferencesOfAnotherComputer());

            testCase.verifyEqual(data(1).RootPath.DiskName, 'LocalName')
            testCase.verifyEqual(data(2).RootPath.DiskName, 'SharedName')
        end
    end
end
