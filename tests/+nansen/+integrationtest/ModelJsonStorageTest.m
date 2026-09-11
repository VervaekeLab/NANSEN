classdef ModelJsonStorageTest < matlab.unittest.TestCase
    %ModelJsonStorageTest Json storage for the data location and variable models
    %
    %   Round trips the two project models that are stored as json through
    %   a real file, with the field shapes that a json round trip would
    %   otherwise change: nested struct arrays, empty and populated cell
    %   arrays, numeric arrays, logicals and an enumeration.
    %
    %   Run tests:
    %       runtests('nansen.integrationtest.ModelJsonStorageTest')

    methods (TestClassSetup)
        function setupProject(testCase)
            % Both model constructors resolve the current project, so the
            % test runs against a throwaway user session and mock project
            % rather than whatever profile is active on the machine.
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (Access = private)

        function folderPath = createConfigFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            folderPath = fullfile(fixture.Folder, 'configurations');
            mkdir(folderPath)
        end

        function model = createDataLocationModel(testCase, filePath)
        %createDataLocationModel Build a model exercising every field shape
        %
        %   Mirrors the two data locations that a new project is given, so
        %   that the model satisfies the invariant that a default data
        %   location must be one that can be written to.
            model = nansen.config.dloc.DataLocationModel(filePath);

            item = model.getBlankItem();
            item.Name = 'Rawdata';
            item.Type = nansen.config.dloc.DataLocationType('recorded');
            item.RootPath(1) = struct('Key', 'aaa-111', ...
                'Value', '/Volumes/DATA/Raw', 'DiskName', 'DATA');
            item.RootPath(2) = struct('Key', 'bbb-222', ...
                'Value', 'D:\Raw', 'DiskName', 'DATA');

            item.SubfolderStructure(1) = model.getDefaultSubfolderStructure();
            item.SubfolderStructure(1).Type = 'Date';
            item.SubfolderStructure(1).Expression = '\d{4}_\d{2}_\d{2}';
            item.SubfolderStructure(2) = model.getDefaultSubfolderStructure();
            item.SubfolderStructure(2).Type = 'Session';
            item.SubfolderStructure(2).IgnoreList = {'temp', 'backup'};

            item.MetaDataDef(2).SubfolderLevel = 2;
            item.MetaDataDef(2).StringDetectInput = '19:end';
            item.MetaDataDef(3).SubfolderLevel = [1 2];
            item.MetaDataDef(3).Separator = '_';

            model.insertItem(item)

            processed = model.getBlankItem();
            processed.Name = 'Processed';
            processed.Type = nansen.config.dloc.DataLocationType('processed');
            model.insertItem(processed)

            model.DefaultDataLocation = 'Processed';
            model.save()

            testCase.assertEqual(numel(model.Data), 2)
        end
    end

    methods (Test)

        function testDataLocationModelRoundTripsThroughJson(testCase)
            folderPath = testCase.createConfigFolder();
            filePath = fullfile(folderPath, 'datalocation_settings.json');

            model = testCase.createDataLocationModel(filePath);
            expected = model.Data;

            testCase.assertTrue(isfile(filePath), ...
                'Inserting an item should have written the json file.')

            reloaded = nansen.config.dloc.DataLocationModel(filePath);
            actual = reloaded.Data;

            testCase.verifyEqual(size(actual), size(expected))
            testCase.verifyEqual({actual.Name}, {expected.Name})
            testCase.verifyEqual({actual.Uuid}, {expected.Uuid})

            actual = actual(1);
            expected = expected(1);

            % The enumeration is stored as text and rebuilt on load
            testCase.verifyClass(actual.Type, 'nansen.config.dloc.DataLocationType')
            testCase.verifyEqual(actual.Type.Name, expected.Type.Name)

            % Nested struct arrays keep their length and orientation
            testCase.verifyEqual(size(actual.RootPath), size(expected.RootPath))
            testCase.verifyEqual({actual.RootPath.Value}, {expected.RootPath.Value})
            testCase.verifyEqual(size(actual.SubfolderStructure), ...
                size(expected.SubfolderStructure))
            testCase.verifyEqual({actual.SubfolderStructure.Type}, ...
                {expected.SubfolderStructure.Type})

            % An empty cell must not come back as []
            testCase.verifyClass(actual.SubfolderStructure(1).IgnoreList, 'cell')
            testCase.verifyEmpty(actual.SubfolderStructure(1).IgnoreList)
            testCase.verifyEqual(actual.SubfolderStructure(2).IgnoreList, ...
                {'temp', 'backup'})

            % Logicals and numeric arrays keep their class and orientation
            testCase.verifyClass(actual.SubfolderStructure(1).IsFolder, 'logical')
            testCase.verifyEqual(actual.MetaDataDef(2).SubfolderLevel, 2)
            testCase.verifyEqual(actual.MetaDataDef(3).SubfolderLevel, [1 2])
            testCase.verifyEmpty(actual.MetaDataDef(1).SubfolderLevel)

            % A windows path survives json escaping
            testCase.verifyEqual(actual.RootPath(2).Value, 'D:\Raw')
        end

        function testVariableModelRoundTripsThroughJson(testCase)
            folderPath = testCase.createConfigFolder();
            filePath = fullfile(folderPath, 'filepath_settings.json');

            model = nansen.config.varmodel.VariableModel(filePath);
            item = model.getDefaultItem('TwoPhotonSeries');
            item.DataLocation = 'Rawdata';
            item.FileNameExpression = '*_raw';
            model.insertItem(item)

            reloaded = nansen.config.varmodel.VariableModel(filePath);

            testCase.verifyEqual(numel(reloaded.Data), 1)
            testCase.verifyEqual(reloaded.Data.VariableName, 'TwoPhotonSeries')
            testCase.verifyEqual(reloaded.Data.FileNameExpression, '*_raw')
            testCase.verifyClass(reloaded.Data.IsCustom, 'logical')
            testCase.verifyTrue(reloaded.Data.IsCustom)
            testCase.verifyEqual(fieldnames(reloaded.Data), fieldnames(model.Data))
        end

        function testJsonFileIsHumanReadableAndItemsAreAnArray(testCase)
            folderPath = testCase.createConfigFolder();
            filePath = fullfile(folderPath, 'datalocation_settings.json');
            testCase.createDataLocationModel(filePath);

            text = fileread(filePath);

            testCase.verifyTrue(contains(text, '"Data": ['), ...
                'Items must be written as a json array.')
            testCase.verifyTrue(contains(text, '"SubfolderStructure": ['), ...
                'A nested list must be a json array even when it holds one element.')
            testCase.verifyTrue(contains(text, '"MetaDataDef": ['), ...
                'A nested list must be a json array.')
            testCase.verifyTrue(contains(text, newline), ...
                'The file should be pretty printed so it can be diffed.')
            testCase.verifyTrue(contains(text, '"Name": "Rawdata"'))
            testCase.verifyTrue(contains(text, '"Type": "recorded"'), ...
                'The enumeration should be stored as its name.')
        end

        function testExistingMatModelIsStillLoaded(testCase)
            % A project written before json storage asks for a json path
            % but has only the mat file beside it.
            folderPath = testCase.createConfigFolder();
            matPath = fullfile(folderPath, 'datalocation_settings.mat');
            testCase.createDataLocationModel(matPath);

            reloaded = nansen.config.dloc.DataLocationModel( ...
                fullfile(folderPath, 'datalocation_settings.json'));

            testCase.verifyEqual(reloaded.FilePath, matPath)
            testCase.verifyEqual(reloaded.Data(1).Name, 'Rawdata')
        end

        function testConvertingAModelFromMatToJson(testCase)
            folderPath = testCase.createConfigFolder();
            matPath = fullfile(folderPath, 'datalocation_settings.mat');
            model = testCase.createDataLocationModel(matPath);

            model.SaveFormat = 'json';
            model.save()

            jsonPath = fullfile(folderPath, 'datalocation_settings.json');
            testCase.verifyTrue(isfile(jsonPath))
            testCase.verifyEqual(model.FilePath, jsonPath)

            reloaded = nansen.config.dloc.DataLocationModel(jsonPath);
            testCase.verifyEqual(reloaded.Data(1).Name, 'Rawdata')
            testCase.verifyEqual({reloaded.Data(1).SubfolderStructure.Type}, ...
                {'Date', 'Session'})
        end
    end
end
