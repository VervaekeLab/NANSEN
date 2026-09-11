classdef VariableLookupTest < matlab.unittest.TestCase
    %VariableLookupTest Resolving a variable name in the variable model
    %
    %   getVariableStructure accepts a variable name, an alias or a file
    %   name expression, and gives back a default item for a name it does
    %   not know. The catalog lookup it starts from raises for an unknown
    %   name, so the fall through to the other lookups must not use it.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.VariableLookupTest')

    properties
        Model
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            % The model constructor resolves the current project.
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createModel(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            filePath = fullfile(fixture.Folder, 'filepath_settings.json');

            testCase.Model = nansen.config.varmodel.VariableModel(filePath);

            item = testCase.Model.getDefaultItem('TwoPhotonSeries');
            item.Alias = 'Imaging';
            item.FileNameExpression = 'two_photon_raw';
            testCase.Model.insertItem(item)
        end
    end

    methods (Test)

        function testLookupByName(testCase)
            [S, isExisting] = testCase.Model.getVariableStructure('TwoPhotonSeries');

            testCase.verifyTrue(isExisting)
            testCase.verifyEqual(S.VariableName, 'TwoPhotonSeries')
        end

        function testLookupByAlias(testCase)
            [S, isExisting] = testCase.Model.getVariableStructure('Imaging');

            testCase.verifyTrue(isExisting)
            testCase.verifyEqual(S.VariableName, 'TwoPhotonSeries')
        end

        function testLookupByFileNameExpression(testCase)
            [S, isExisting] = testCase.Model.getVariableStructure('two_photon_raw');

            testCase.verifyTrue(isExisting)
            testCase.verifyEqual(S.VariableName, 'TwoPhotonSeries')
        end

        function testUnknownNameGivesADefaultItem(testCase)
            % Loading or saving a variable that is not yet in the model
            % starts here, so an unknown name is an expected input.
            [S, isExisting] = testCase.Model.getVariableStructure('NotAVariable');

            testCase.verifyFalse(isExisting)
            testCase.verifyEqual(S.VariableName, 'NotAVariable')
            testCase.verifyTrue(S.IsCustom)
        end
    end
end
