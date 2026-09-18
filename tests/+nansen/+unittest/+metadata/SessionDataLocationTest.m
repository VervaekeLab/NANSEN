classdef SessionDataLocationTest < matlab.unittest.TestCase
    %SessionDataLocationTest Resolve a session's data locations against a data location model
    %
    %   A new project has default data locations with no root path until
    %   they are configured. A session built while such a location exists
    %   must still resolve the locations that do have a root.
    %
    %   Run tests:
    %       runtests('nansen.unittest.metadata.SessionDataLocationTest')

    properties
        Model
        SessionFolder char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createModel(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            root = testCase.applyFixture(TemporaryFolderFixture).Folder;

            dataFolder = fullfile(root, 'data');
            testCase.SessionFolder = fullfile(dataFolder, 'session1');
            mkdir(testCase.SessionFolder)

            testCase.Model = nansen.config.dloc.DataLocationModel( ...
                fullfile(root, 'datalocation_settings.mat'));

            configured = nansen.config.dloc.DataLocationModel.getBlankItem();
            configured.Name = 'Raw';
            configured.Type = nansen.config.dloc.DataLocationType('recorded');
            configured.RootPath = struct('Key', nansen.util.getuuid(), 'Value', dataFolder, ...
                'DiskName', '', 'DiskType', 'Local');
            testCase.Model.addDataLocation(configured)

            unconfigured = nansen.config.dloc.DataLocationModel.getBlankItem();
            unconfigured.Name = 'Processed';
            unconfigured.Type = nansen.config.dloc.DataLocationType('processed');
            testCase.Model.addDataLocation(unconfigured)
        end
    end

    methods (Test)
        function testLocationWithoutRootPathDoesNotStopSession(testCase)
            testCase.assertEmpty(testCase.Model.getDataLocation('Processed').RootPath)

            session = nansen.metadata.type.Session( ...
                struct('Raw', testCase.SessionFolder, 'Processed', ''), ...
                'DataLocationModel', testCase.Model);

            raw = session.DataLocation(strcmp({session.DataLocation.Name}, 'Raw'));
            testCase.verifyEqual(raw.RootUid, testCase.Model.getDataLocation('Raw').RootPath.Key)
            processed = session.DataLocation(strcmp({session.DataLocation.Name}, 'Processed'));
            testCase.verifyEmpty(processed.RootUid)
        end
    end
end
