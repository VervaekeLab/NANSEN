classdef SessionDataLocationFieldsTest < matlab.unittest.TestCase
    %SessionDataLocationFieldsTest How a session fills in its data location fields
    %
    %   A session stores which root path of the data location model its
    %   data is under, and derives the path, index and disk name of that
    %   root from the model.
    %
    %   The tests run inside a temporary project and use its first session,
    %   with a second root path added to its data location.
    %
    %   Run tests:
    %       runtests('nansen.unittest.session.SessionDataLocationFieldsTest')

    properties (Constant)
        SecondRootPath = fullfile(tempdir, 'second_root_for_session_tests')
    end

    properties
        Model
        Item
        Entry
        Session
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Create a project whose data location has two roots
            testCase.applyFixture(nansen.fixture.ProjectFixture())
            project = nansen.getCurrentProject();
            testCase.Model = project.DataLocationModel;

            item = testCase.Model.getItem(1);
            rootPaths = item.RootPath;
            rootPaths(2).Key = nansen.util.getuuid();
            rootPaths(2).Value = testCase.SecondRootPath;
            rootPaths(2).DiskName = 'SecondDisk';
            rootPaths(2).DiskType = 'External';
            testCase.Model.modifyDataLocation(item.Name, 'RootPath', rootPaths);
            testCase.Item = testCase.Model.getItem(1);

            sessionTable = project.MetaTableCatalog.getMetaTable('Session');
            testCase.Entry = sessionTable.entries(1,:);
        end
    end

    methods (TestMethodSetup)
        function createSession(testCase)
            testCase.Session = testCase.makeSession(testCase.Entry);
        end
    end

    methods (Access = private)

        function session = makeSession(testCase, entry)
            session = nansen.metadata.type.Session(entry, ...
                'DataLocationModel', testCase.Model);
        end

        function entry = entryWithStoredField(testCase, fieldName, value)
        %entryWithStoredField Table row with one stored field replaced
        %
        %   The derived fields are expanded again from the stored ones, as
        %   a metatable does when it reads a file.
            entry = testCase.Entry;
            stored = testCase.Model.reduceDataLocationInfo(entry.DataLocation);
            stored(1).(fieldName) = value;
            entry.DataLocation = testCase.Model.expandDataLocationInfo(stored);
        end
    end

    methods (Test)

        function testSessionDerivesFieldsFromTheModel(testCase)
            dataLocation = testCase.Session.DataLocation(1);

            testCase.verifyEqual(dataLocation.Name, testCase.Item.Name)
            testCase.verifyEqual(dataLocation.Type.Name, testCase.Item.Type.Name)
            testCase.verifyEqual(dataLocation.RootUid, testCase.Item.RootPath(1).Key)
            testCase.verifyEqual(dataLocation.RootPath, testCase.Item.RootPath(1).Value)
            testCase.verifyEqual(dataLocation.RootIdx, 1)
            testCase.verifyEqual(dataLocation.Diskname, testCase.Item.RootPath(1).DiskName)
        end

        function testEmptyRootUidUsesTheLastRootPath(testCase)
            session = testCase.makeSession(testCase.entryWithStoredField('RootUid', ''));

            dataLocation = session.DataLocation(1);
            testCase.verifyEqual(dataLocation.RootUid, testCase.Item.RootPath(2).Key)
            testCase.verifyEqual(dataLocation.RootPath, testCase.SecondRootPath)
            testCase.verifyEqual(dataLocation.RootIdx, 2)
            testCase.verifyEqual(dataLocation.Diskname, 'SecondDisk')
        end

        function testUnknownRootUidIsKeptUnresolved(testCase)
            session = testCase.makeSession( ...
                testCase.entryWithStoredField('RootUid', 'not-a-root-of-this-model'));

            dataLocation = session.DataLocation(1);
            testCase.verifyEqual(dataLocation.RootUid, 'not-a-root-of-this-model')
            testCase.verifyEqual(dataLocation.Name, testCase.Item.Name)
            testCase.verifyEmpty(dataLocation.RootIdx)
            testCase.verifyEmpty(dataLocation.RootPath)
        end

        function testUnknownDataLocationRaises(testCase)
            entry = testCase.entryWithStoredField('Uuid', ...
                '6f2b7c1e-3d4a-4f8e-9a0b-1c2d3e4f5a61');

            testCase.verifyError(@() testCase.makeSession(entry), ...
                'NANSEN:StorableCatalog:ItemNotFound')
        end

        function testLegacyDataLocationIsConverted(testCase)
            subfolder = fullfile('sub-01', 'ses-01');
            session = testCase.Session;
            session.DataLocation = struct(testCase.Item.Name, ...
                fullfile(testCase.SecondRootPath, subfolder));

            session.fixDataLocations()

            dataLocation = session.DataLocation(1);
            testCase.verifyEqual(dataLocation.Uuid, testCase.Item.Uuid)
            testCase.verifyEqual(dataLocation.RootUid, testCase.Item.RootPath(2).Key)
            testCase.verifyEqual(dataLocation.Subfolders, [filesep, subfolder])
            testCase.verifyEqual(dataLocation.RootIdx, 2)
            testCase.verifyEqual(dataLocation.Diskname, 'SecondDisk')
        end

        function testLegacyDataLocationOutsideTheRootsIsMarked(testCase)
            session = testCase.Session;
            session.DataLocation = struct(testCase.Item.Name, ...
                fullfile(tempdir, 'somewhere_else', 'sub-01'));

            session.fixDataLocations()

            testCase.verifyTrue(isnan(session.DataLocation(1).RootIdx))
            testCase.verifyEqual(session.DataLocation(1).Diskname, 'N/A')
        end

        function testUpdateRootDirPathSelectsTheNamedRoot(testCase)
            session = testCase.Session;

            session.updateRootDirPath(testCase.Item.Name, testCase.SecondRootPath)

            dataLocation = session.DataLocation(1);
            testCase.verifyEqual(dataLocation.RootUid, testCase.Item.RootPath(2).Key)
            testCase.verifyEqual(dataLocation.RootPath, testCase.SecondRootPath)
            testCase.verifyEqual(dataLocation.RootIdx, 2)
            testCase.verifyEqual(dataLocation.Diskname, 'SecondDisk')
        end

        function testUpdateRootDirPathRejectsAnUnknownRoot(testCase)
            testCase.verifyError( ...
                @() testCase.Session.updateRootDirPath(testCase.Item.Name, ...
                    fullfile(tempdir, 'not_a_root')), ...
                'NANSEN:Session:InvalidRootPath')
        end

        function testUpdateRootDirSelectsTheNamedRoot(testCase)
            session = testCase.Session;
            newRoots = struct(testCase.Item.Name, struct('RootPath', testCase.SecondRootPath));

            session.updateRootDir(newRoots)

            dataLocation = session.DataLocation(1);
            testCase.verifyEqual(dataLocation.RootUid, testCase.Item.RootPath(2).Key)
            testCase.verifyEqual(dataLocation.RootPath, testCase.SecondRootPath)
            testCase.verifyEqual(dataLocation.Diskname, 'SecondDisk')
        end

        function testUpdateRootDirStoresANumericIndex(testCase)
            % The tooltip of the DataLocation table variable prints this
            % value as a root number.
            session = testCase.Session;
            newRoots = struct(testCase.Item.Name, struct('RootPath', testCase.SecondRootPath));

            session.updateRootDir(newRoots)

            testCase.verifyEqual(session.DataLocation(1).RootIdx, 2)
        end

        function testValidatingPathsFillsAStoredDataLocation(testCase)
            stored = testCase.Model.reduceDataLocationInfo(testCase.Entry.DataLocation);
            stored(1).RootUid = testCase.Item.RootPath(2).Key;

            validated = testCase.Model.validateDataLocationPaths(stored);

            testCase.verifyEqual(validated(1).RootPath, testCase.SecondRootPath)
            testCase.verifyEqual(validated(1).RootIdx, 2)
            testCase.verifyEqual(validated(1).Diskname, 'SecondDisk')
        end
    end
end
