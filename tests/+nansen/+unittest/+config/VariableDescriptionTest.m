classdef VariableDescriptionTest < matlab.unittest.TestCase
%VariableDescriptionTest - The Description field of data variables
%
%   Items, such as those of module templates, can lack fields that the
%   blank item has. A model saved without a Description field and an item
%   made without one must still load and insert.
%
%   Run tests:
%       runtests('nansen.unittest.config.VariableDescriptionTest')

    properties
        FilePath char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            % The model constructor resolves the current project.
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createModelFile(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folder = testCase.applyFixture(TemporaryFolderFixture).Folder;
            testCase.FilePath = fullfile(folder, 'filepath_settings.json');
        end
    end

    methods (Test)
        function testBlankItemHasEmptyDescription(testCase)
            item = nansen.config.varmodel.VariableModel.getBlankItem();
            testCase.verifyEqual(item.Description, '')
        end

        function testItemWithoutDescriptionIsInserted(testCase)
            % Module templates are JSON files written without the field
            model = nansen.config.varmodel.VariableModel(testCase.FilePath);
            item = rmfield(model.getDefaultItem('Template'), 'Description');

            model.insertItem(item);

            testCase.verifyEqual(model.getItem('Template').Description, '')
        end

        function testModelSavedWithoutDescriptionLoadsWithIt(testCase)
            model = nansen.config.varmodel.VariableModel(testCase.FilePath);
            item = model.getDefaultItem('Saved');
            item.Description = 'Membrane potential in mV';
            model.insertItem(item);
            model.save()

            S = jsondecode(fileread(testCase.FilePath));
            S.Data = rmfield(S.Data, 'Description');
            writelines(jsonencode(S), testCase.FilePath)

            reloaded = nansen.config.varmodel.VariableModel(testCase.FilePath);

            testCase.verifyEqual(reloaded.getItem('Saved').Description, '')
        end
    end
end
