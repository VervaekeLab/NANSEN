classdef ImportDatasetStructureModelTest < matlab.unittest.TestCase
    %ImportDatasetStructureModelTest Import a Dataset Structure Model and detect sessions with NANSEN
    %
    %   Imports the model written for Garad and Lessmann (2022) into data
    %   location and variable models, then asks NANSEN's own session
    %   detection what it finds in a folder laid out like that dataset. The
    %   folder is synthetic: it follows the naming convention in the model,
    %   <yyMMdd>_<slice><repeat>.ABF, with two cells of five repeats, plus
    %   the descriptor, licence and a hidden file that must be skipped.
    %
    %   Run tests:
    %       runtests('nansen.integrationtest.ImportDatasetStructureModelTest')

    properties
        DataFolder char
        DataLocationModel
        VariableModel
        Report
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function importGarad(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            root = testCase.applyFixture(TemporaryFolderFixture).Folder;

            testCase.DataFolder = fullfile(root, 'garad-2022');
            mkdir(testCase.DataFolder)
            fileNames = [ ...
                compose("170518_1%s.ABF", ["a", "b", "c", "d", "e"]), ...
                compose("170519_2%s.ABF", ["a", "b", "c", "d", "e"]), ...
                "EBRAINS-datadescriptor_garad.pdf", "Licence-CC-BY.pdf", ".DS_Store"];
            for fileName = fileNames
                fclose(fopen(fullfile(testCase.DataFolder, fileName), 'w'));
            end

            fixture = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                '+fixture', 'datasetstructure', 'garad-2022.json');
            dsm = jsondecode(fileread(fixture));
            dsm.dataLocations.filesystemSource.rootStoragePaths.path = testCase.DataFolder;

            configFolder = fullfile(root, 'configurations');
            mkdir(configFolder)
            dataLocationPath = fullfile(configFolder, 'datalocation_settings.json');
            variablePath = fullfile(configFolder, 'filepath_settings.json');

            testCase.Report = nansen.config.dloc.importDatasetStructureModel(dsm, ...
                nansen.config.dloc.DataLocationModel(dataLocationPath), ...
                nansen.config.varmodel.VariableModel(variablePath));

            % Read both back, as a project would on its next start
            testCase.DataLocationModel = nansen.config.dloc.DataLocationModel(dataLocationPath);
            testCase.VariableModel = nansen.config.varmodel.VariableModel(variablePath);
        end
    end

    methods (Access = private)
        function paths = sessionPaths(testCase)
            sessionFolders = nansen.dataio.session.listSessionFolders( ...
                testCase.DataLocationModel, 'garad');
            paths = reshape(sessionFolders.garad, 1, []);
        end
    end

    methods (Test)

        function testImportedModelsLoadFromDisk(testCase)
            % The only data location is read-only, so there is no default.
            % Loading such a model used to raise.
            testCase.verifyEqual(testCase.DataLocationModel.DataLocationNames, {'garad'})
            testCase.verifyEmpty(testCase.DataLocationModel.DefaultDataLocation)
            testCase.verifyEqual(testCase.VariableModel.getItem('abf').FileType, '.ABF')
        end

        function testEachAbfFileIsASession(testCase)
            paths = testCase.sessionPaths();

            testCase.verifyNumElements(paths, 10, ...
                'The descriptor, licence and hidden file must not be sessions.')

            [~, names, extensions] = fileparts(paths);
            testCase.verifyEqual(unique(extensions), {'.ABF'})
            testCase.verifyEqual(sort(names), ...
                sort(cellstr([compose("170518_1%s", ["a" "b" "c" "d" "e"]), ...
                              compose("170519_2%s", ["a" "b" "c" "d" "e"])])))
        end

        function testSessionAndSubjectIdsComeFromTheFileNames(testCase)
            model = testCase.DataLocationModel;
            index = model.getItemIndex('garad');
            paths = testCase.sessionPaths();

            sessionIds = cellfun(@(p) model.getSessionID(p, index), paths, 'UniformOutput', false);
            subjectIds = cellfun(@(p) model.getSubjectID(p, index), paths, 'UniformOutput', false);

            [~, names] = fileparts(paths);
            testCase.verifyEqual(sessionIds, names, ...
                'The session id is the file name without its extension.')
            testCase.verifyEqual(unique(subjectIds), {'170518_1', '170519_2'}, ...
                'The subject is the cell: the date and slice number.')
        end

        function testExperimentDateIsParsed(testCase)
            model = testCase.DataLocationModel;
            paths = testCase.sessionPaths();
            firstPath = paths{contains(paths, '170518_1a')};

            experimentDate = model.getDate(firstPath, model.getItemIndex('garad'));

            testCase.verifyEqual([year(experimentDate), month(experimentDate), day(experimentDate)], ...
                [2017, 5, 18])
        end

        function testSessionsAreMatchedOnePerFile(testCase)
            sessionFolders = nansen.dataio.session.listSessionFolders(testCase.DataLocationModel, 'all');
            matched = nansen.dataio.session.matchSessionFolders(testCase.DataLocationModel, sessionFolders);

            testCase.verifyNumElements(matched, 10, ...
                'Grouping by session id must not merge the repeats of a cell.')
        end

        function testVariableIsLinkedToItsDataLocation(testCase)
            variable = testCase.VariableModel.getItem('abf');
            dataLocation = testCase.DataLocationModel.getDataLocation('garad');

            testCase.verifyEqual(variable.DataLocationUuid, dataLocation.Uuid, ...
                'Adding the data location assigns a new uuid; the variable must follow it.')
        end

        function testVariableFindsTheSessionsFile(testCase)
            % A session stored as a file shares its folder with every other
            % session. NANSEN narrows the folder to the files containing
            % the session id, as done here.
            fileName = testCase.VariableModel.lookForFile(testCase.DataFolder, 'abf', ...
                'FilterFcn', @(names) contains(names, '170519_2c'));

            testCase.verifyEqual(fileName, '170519_2c.ABF')
        end

        function testReportIsReturned(testCase)
            testCase.verifyClass(testCase.Report, 'table')
            testCase.verifyTrue(any(contains(testCase.Report.Element, "slice_number")))
        end
    end
end
