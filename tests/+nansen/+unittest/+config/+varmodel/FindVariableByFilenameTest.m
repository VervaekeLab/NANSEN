classdef FindVariableByFilenameTest < matlab.unittest.TestCase
    %FindVariableByFilenameTest Matching a file name to variables in the model
    %
    %   The file viewer shows one data location per tab, so a file in a tab
    %   can only belong to variables stored in that data location. These
    %   tests cover the DataLocation filter of findVariableByFilename and
    %   the matching it scopes.
    %
    %   Inserting a variable looks up file adapters through the current
    %   project, so the tests run inside a temporary project. Each test then
    %   works on a model stored in a temporary folder of its own.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.varmodel.FindVariableByFilenameTest')

    properties
        ModelFilePath
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Provide the project the file adapter lookup needs
            testCase.applyFixture(nansen.fixture.ProjectFixture())
        end
    end

    methods (TestMethodSetup)
        function useIsolatedModelFile(testCase)
        %useIsolatedModelFile Store the model in a temporary folder

            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.ModelFilePath = fullfile(fixture.Folder, 'variable_model.mat');
        end
    end

    methods (Test)

        function testAllDataLocationsAreSearchedByDefault(testCase)
        %testAllDataLocationsAreSearchedByDefault Without a filter every data location counts
            model = testCase.createModel();
            model.insertItem( testCase.createItem('RawRois', 'Rawdata', 'rois', '.mat') )
            model.insertItem( testCase.createItem('ProcessedRois', 'Processed', 'rois', '.mat') )

            varNames = model.findVariableByFilename('m001_rois.mat', 'all');

            testCase.verifyEqual(sort(varNames), {'ProcessedRois', 'RawRois'})
        end

        function testDataLocationRestrictsMatches(testCase)
        %testDataLocationRestrictsMatches Only variables of the named data location match
            model = testCase.createModel();
            model.insertItem( testCase.createItem('RawRois', 'Rawdata', 'rois', '.mat') )
            model.insertItem( testCase.createItem('ProcessedRois', 'Processed', 'rois', '.mat') )

            varName = model.findVariableByFilename('m001_rois.mat', 'all', ...
                'DataLocation', 'Processed');

            testCase.verifyEqual(varName, 'ProcessedRois')
        end

        function testFileTypeFallbackIsScopedToDataLocation(testCase)
        %testFileTypeFallbackIsScopedToDataLocation A file type match must be unique
        %   within the data location, not across the whole model
            model = testCase.createModel();
            model.insertItem( testCase.createItem('RawNwb', 'Rawdata', '', '.nwb') )
            model.insertItem( testCase.createItem('ProcessedNwb', 'Processed', '', '.nwb') )

            unscoped = model.findVariableByFilename('m001.nwb', 'all');
            scoped = model.findVariableByFilename('m001.nwb', 'all', ...
                'DataLocation', 'Rawdata');

            testCase.verifyEmpty(unscoped)
            testCase.verifyEqual(scoped, 'RawNwb')
        end

        function testVariableWithoutDataLocationBelongsToDefault(testCase)
        %testVariableWithoutDataLocationBelongsToDefault An empty data location is the default one
            model = testCase.createModel();
            model.insertItem( testCase.createItem('Notes', '', 'notes', '.mat') )

            inDefault = model.findVariableByFilename('m001_notes.mat', 'all', ...
                'DataLocation', 'Rawdata', 'DefaultDataLocation', 'Rawdata');
            inOther = model.findVariableByFilename('m001_notes.mat', 'all', ...
                'DataLocation', 'Processed', 'DefaultDataLocation', 'Rawdata');

            testCase.verifyEqual(inDefault, 'Notes')
            testCase.verifyEmpty(inOther)
        end

        function testVariableWithoutDataLocationIsKeptWhenDefaultIsUnknown(testCase)
        %testVariableWithoutDataLocationIsKeptWhenDefaultIsUnknown Without the default's
        %   name a variable with an empty data location is never filtered out
            model = testCase.createModel();
            model.insertItem( testCase.createItem('Notes', '', 'notes', '.mat') )

            varName = model.findVariableByFilename('m001_notes.mat', 'all', ...
                'DataLocation', 'Processed');

            testCase.verifyEqual(varName, 'Notes')
        end
    end

    methods (Access = private)
        function model = createModel(testCase)
            model = nansen.config.varmodel.VariableModel(testCase.ModelFilePath);
        end
    end

    methods (Static, Access = private)
        function item = createItem(variableName, dataLocationName, fileNameExpression, fileType)
            item = nansen.config.varmodel.VariableModel.getDefaultItem(variableName);
            item.DataLocation = dataLocationName;
            item.FileNameExpression = fileNameExpression;
            item.FileType = fileType;
        end
    end
end
