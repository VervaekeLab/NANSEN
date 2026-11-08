classdef DefaultDataLocationTest < matlab.unittest.TestCase
    %DefaultDataLocationTest Choosing a default data location for a model that has none
    %
    %   A default data location has to be one that can be written to. The
    %   model picks one when its preferences do not name one yet, which
    %   happens on every model saved before that preference existed.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.DefaultDataLocationTest')

    properties
        ModelPath char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            % The model constructor resolves the current project, so the
            % test runs against a mock project rather than whatever
            % profile is active on the machine.
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createModelPath(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.ModelPath = fullfile(fixture.Folder, 'datalocation_settings.json');
        end
    end

    methods (Access = private)

        function model = modelWithTypes(testCase, varargin)
        %modelWithTypes Build a model whose data locations have given types
            model = nansen.config.dloc.DataLocationModel(testCase.ModelPath);

            for i = 1:numel(varargin)
                item = model.getBlankItem();
                item.Name = sprintf('Location%d', i);
                item.Type = nansen.config.dloc.DataLocationType(varargin{i});
                model.insertItem(item)
            end
        end

        function model = reload(~, model)
        %reload Read the model back, which is when a default is chosen
            model.save()
            model = nansen.config.dloc.DataLocationModel(model.FilePath);
        end

        function model = reloadWithoutTypes(testCase, model)
        %reloadWithoutTypes Read the model back from a file without types
        %
        %   Writes the model as a mat file without the Type field and
        %   without a default data location, which is how models were
        %   saved before data locations had a type. The file name has no
        %   json file beside it, because a json file would be read instead.

            filePath = fullfile(fileparts(testCase.ModelPath), 'untyped_settings.mat');
            model.saveas(filePath)

            S = load(filePath, 'Data', 'Preferences');
            S.Data = rmfield(S.Data, 'Type');
            if isfield(S.Preferences, 'DefaultDataLocation')
                S.Preferences = rmfield(S.Preferences, 'DefaultDataLocation');
            end
            save(filePath, '-struct', 'S')

            model = nansen.config.dloc.DataLocationModel(filePath);
        end
    end

    methods (Test)

        function testTheFirstWritableLocationBecomesTheDefault(testCase)
            model = testCase.modelWithTypes('recorded', 'processed');

            model = testCase.reload(model);

            testCase.verifyEqual(model.DefaultDataLocation, 'Location2')
        end

        function testAModelOfOnlyReadOnlyLocationsLoads(testCase)
            % A model whose only data location is read only has no default,
            % and loading it must not assign one anyway.
            model = testCase.modelWithTypes('recorded');

            model = testCase.reload(model);

            testCase.verifyEmpty(model.DefaultDataLocation)
            testCase.verifyEqual(numel(model.Data), 1)
            testCase.verifyFalse(isfield(model.Preferences, 'DefaultDataLocation'), ...
                'No default is recorded, so one can be picked once a writable location exists.')
        end

        function testAModelWithoutADefaultSaysHowToAddOne(testCase)
            % New data needs a writable location. Asking for the default of
            % a model that has none names the problem instead of failing in
            % the name lookup.
            model = testCase.modelWithTypes('recorded');

            model = testCase.reload(model);

            testCase.verifyError(@() model.getDefaultDataLocation(), ...
                'NANSEN:DataLocationModel:NoDefaultDataLocation')
        end

        function testADefaultIsPickedOnceAWritableLocationExists(testCase)
            model = testCase.modelWithTypes('recorded');
            model = testCase.reload(model);
            testCase.assertEmpty(model.DefaultDataLocation)

            item = model.getBlankItem();
            item.Name = 'Location2';
            item.Type = nansen.config.dloc.DataLocationType('processed');
            model.insertItem(item)

            model = testCase.reload(model);

            testCase.verifyEqual(model.DefaultDataLocation, 'Location2')
        end

        function testUntypedModelMakesTheSecondLocationTheDefault(testCase)
            % A model saved before data locations had a type kept its
            % processed data in the second location.
            model = testCase.modelWithTypes('recorded', 'recorded', 'recorded');

            model = testCase.reloadWithoutTypes(model);

            testCase.verifyEqual(arrayfun(@(item) item.Type.Name, model.Data, ...
                'UniformOutput', false), {'recorded', 'processed', 'recorded'})
            testCase.verifyEqual(model.DefaultDataLocation, 'Location2')
        end

        function testUntypedModelWithOneLocationMakesItTheDefault(testCase)
            % The only location held the processed data too, so it has to
            % be writable to be the default.
            model = testCase.modelWithTypes('recorded');

            model = testCase.reloadWithoutTypes(model);

            testCase.verifyEqual(model.Data(1).Type.Name, 'processed')
            testCase.verifyEqual(model.DefaultDataLocation, 'Location1')
        end

        function testTypesAreNotOverwritten(testCase)
            % Choosing a default must not change the type of any data
            % location.
            model = testCase.modelWithTypes('processed', 'curated');

            model = testCase.reload(model);

            testCase.verifyEqual(model.Data(1).Type.Name, 'processed')
            testCase.verifyEqual(model.Data(2).Type.Name, 'curated', ...
                'The type of a data location must not be changed by choosing a default.')
            testCase.verifyEqual(model.DefaultDataLocation, 'Location1')
        end
    end
end
