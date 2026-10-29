classdef FileNameExpressionTest < matlab.unittest.TestCase
    %FileNameExpressionTest Proposing and checking a file name expression for a file
    %
    %   When a variable is created from an existing file, the model proposes
    %   an expression from the file name and checks that the expression
    %   finds the file. These tests cover both.
    %
    %   Constructing a model looks up file adapters through the current
    %   project, so the tests run inside a temporary project. Each test
    %   works on a model stored in a temporary folder of its own.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.varmodel.FileNameExpressionTest')

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

        function testSuggestionRemovesSessionIdAndSeparators(testCase)
        %testSuggestionRemovesSessionIdAndSeparators The rest of the name is the expression
            import nansen.config.varmodel.VariableModel

            testCase.verifyEqual( ...
                VariableModel.suggestFileNameExpression('m001_two_photon.raw', 'm001'), 'two_photon')
            testCase.verifyEqual( ...
                VariableModel.suggestFileNameExpression('two_photon-m001.raw', 'm001'), 'two_photon')
        end

        function testSuggestionIsStarWhenOnlySessionIdRemains(testCase)
        %testSuggestionIsStarWhenOnlySessionIdRemains A session-named file gets a star
            import nansen.config.varmodel.VariableModel

            testCase.verifyEqual( VariableModel.suggestFileNameExpression('m001.nwb', 'm001'), '*' )
        end

        function testSuggestionKeepsNameWithoutSessionId(testCase)
        %testSuggestionKeepsNameWithoutSessionId A name without the ID is used as it is
            import nansen.config.varmodel.VariableModel

            testCase.verifyEqual( VariableModel.suggestFileNameExpression('rois.mat', 'm001'), 'rois' )
            testCase.verifyEqual( VariableModel.suggestFileNameExpression('m001_rois.mat', ''), 'm001_rois' )
        end

        function testPartOfNameMatches(testCase)
        %testPartOfNameMatches An expression matches when it occurs in a file of its type
            model = testCase.createModel();

            testCase.verifyTrue( model.isFileNameMatch('m001_rois.mat', 'rois', '.mat') )
            testCase.verifyFalse( model.isFileNameMatch('m001_rois.mat', 'dff', '.mat') )
            testCase.verifyFalse( model.isFileNameMatch('m001_rois.nwb', 'rois', '.mat') )
        end

        function testStarMatchesAnyFileOfType(testCase)
        %testStarMatchesAnyFileOfType A star matches every file of the type and nothing else
            model = testCase.createModel();

            testCase.verifyTrue( model.isFileNameMatch('m001.nwb', '*', '.nwb') )
            testCase.verifyTrue( model.isFileNameMatch('m001.nwb', '*', 'nwb') )
            testCase.verifyFalse( model.isFileNameMatch('m001.mat', '*', '.nwb') )
        end

        function testAnchoredExpressionMatchesFromTheStart(testCase)
        %testAnchoredExpressionMatchesFromTheStart A leading caret pins the expression to the start
            model = testCase.createModel();

            testCase.verifyTrue( model.isFileNameMatch('rois_m001.mat', '^rois', '.mat') )
            testCase.verifyFalse( model.isFileNameMatch('m001_rois.mat', '^rois', '.mat') )
        end
    end

    methods (Access = private)
        function model = createModel(testCase)
            model = nansen.config.varmodel.VariableModel(testCase.ModelFilePath);
        end
    end
end
