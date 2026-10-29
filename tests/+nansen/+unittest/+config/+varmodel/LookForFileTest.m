classdef LookForFileTest < matlab.unittest.TestCase
    %LookForFileTest Locating a variable's file in a folder
    %
    %   lookForFile turns a variable's file name expression into a search
    %   for a file. An expression with placeholders names the whole file
    %   once expanded; any other expression is a part of the file name.
    %
    %   Constructing a model looks up file adapters through the current
    %   project, so the tests run inside a temporary project. Each test
    %   works in a temporary folder of its own, which holds the model file
    %   and the files searched.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.varmodel.LookForFileTest')

    properties
        Folder
    end

    methods (TestClassSetup)
        function useTemporaryProject(testCase)
        %useTemporaryProject Provide the project the file adapter lookup needs
            testCase.applyFixture(nansen.fixture.ProjectFixture())
        end
    end

    methods (TestMethodSetup)
        function useIsolatedFolder(testCase)
        %useIsolatedFolder Create the files to search in a temporary folder

            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;

            fileNames = {'m001.nwb', 'm001_extra.nwb', 'm002.nwb', 'm001_rois.mat'};
            for i = 1:numel(fileNames)
                fclose( fopen(fullfile(testCase.Folder, fileNames{i}), 'w') );
            end
        end
    end

    methods (Test)

        function testPlaceholderFindsExactFile(testCase)
        %testPlaceholderFindsExactFile An expanded placeholder expression names one file
            model = testCase.createModel();
            item = testCase.createItem('SessionNwb', '{sessionID}', '.nwb');

            fileName = model.lookForFile(testCase.Folder, item, ...
                'PlaceholderValues', struct('sessionID', 'm001'));

            testCase.verifyEqual(fileName, 'm001.nwb')
        end

        function testPlaceholderWithoutValueIsAnError(testCase)
        %testPlaceholderWithoutValueIsAnError A placeholder cannot be searched for without its value
            model = testCase.createModel();
            item = testCase.createItem('SessionNwb', '{sessionID}', '.nwb');

            testCase.verifyError(@() model.lookForFile(testCase.Folder, item), ...
                'NANSEN:VariableModel:MissingPlaceholderValue')
        end

        function testFilterNarrowsPlaceholderMatches(testCase)
        %testFilterNarrowsPlaceholderMatches The filter applies after a wildcard search
            model = testCase.createModel();
            item = testCase.createItem('SessionFiles', '{sessionID}*', '.nwb');

            fileName = model.lookForFile(testCase.Folder, item, ...
                'PlaceholderValues', struct('sessionID', 'm001'), ...
                'FilterFcn', @(names) contains(names, 'extra'));

            testCase.verifyEqual(fileName, 'm001_extra.nwb')
        end

        function testPlainExpressionMatchesPartOfName(testCase)
        %testPlainExpressionMatchesPartOfName An expression without placeholders is a part of the name
            model = testCase.createModel();
            item = testCase.createItem('Rois', 'rois', '.mat');

            testCase.verifyEqual(model.lookForFile(testCase.Folder, item), 'm001_rois.mat')
        end
    end

    methods (Access = private)
        function model = createModel(testCase)
            modelFilePath = fullfile(testCase.Folder, 'variable_model.mat');
            model = nansen.config.varmodel.VariableModel(modelFilePath);
        end
    end

    methods (Static, Access = private)
        function item = createItem(variableName, fileNameExpression, fileType)
            item = nansen.config.varmodel.VariableModel.getDefaultItem(variableName);
            item.FileNameExpression = fileNameExpression;
            item.FileType = fileType;
        end
    end
end
