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
