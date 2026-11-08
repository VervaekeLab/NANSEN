classdef DataLocationModelPersistenceTest < matlab.unittest.TestCase
    %DataLocationModelPersistenceTest What loading a data location model writes
    %
    %   Loading applies migrations and refreshes derived values. The file
    %   is written when that changes its content and left alone otherwise.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.DataLocationModelPersistenceTest')

    properties
        FolderPath char
    end

    methods (TestClassSetup)
        function setupProject(testCase)
            % The model constructor resolves the current project.
            testCase.applyFixture(nansen.fixture.ProjectFixture)
        end
    end

    methods (TestMethodSetup)
        function createFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.FolderPath = fixture.Folder;
        end
    end

    methods (Access = private)

        function filePath = createSettledModel(testCase, extension)
        %createSettledModel Write a model file that a load has nothing to add to
        %
        %   The data location has no root paths, so its empty list carries
        %   none of the fields that a root path migration looks for.
            filePath = fullfile(testCase.FolderPath, "datalocation_settings." + extension);

            model = nansen.config.dloc.DataLocationModel(char(filePath));
            item = model.getBlankItem();
            item.Name = 'Processed';
            item.Type = nansen.config.dloc.DataLocationType('processed');
            model.insertItem(item)

            nansen.config.dloc.DataLocationModel(char(filePath));
        end

        function modifyJsonFile(~, filePath, modifyFcn)
        %modifyJsonFile Apply a function to the decoded content of a json file
            S = jsondecode(fileread(filePath));
            S = modifyFcn(S);
            utility.filewrite(filePath, jsonencode(S, 'PrettyPrint', true))
        end
    end

    methods (Test)

        function testLoadingUnchangedJsonLeavesTheFileAlone(testCase)
            % Whitespace does not change the content, so it survives only
            % if the file is not written.
            filePath = testCase.createSettledModel("json");
            paddedText = [fileread(filePath), newline, newline];
            utility.filewrite(filePath, paddedText)

            nansen.config.dloc.DataLocationModel(char(filePath));

            testCase.verifyEqual(string(fileread(filePath)), string(paddedText), ...
                'Loading a model that has nothing to change must not write its file.')
        end

        function testLoadingUnchangedMatLeavesTheFileAlone(testCase)
            % Saving replaces the file with the catalog variables, so a
            % variable the catalog does not know survives only if the file
            % is not written.
            filePath = testCase.createSettledModel("mat");
            Marker = true;
            save(filePath, 'Marker', '-append')

            nansen.config.dloc.DataLocationModel(char(filePath));

            testCase.verifyTrue(any(strcmp(who('-file', filePath), 'Marker')), ...
                'Loading a model that has nothing to change must not write its file.')
        end

        function testGeneratedUuidsReachTheFile(testCase)
            % A uuid generated on load has to be stored. A data location is
            % referred to by its uuid, so it must be the same next time.
            filePath = testCase.createSettledModel("json");
            testCase.modifyJsonFile(filePath, @(S) setfield(S, 'Data', rmfield(S.Data, 'Uuid')))

            firstLoad = nansen.config.dloc.DataLocationModel(char(filePath));
            secondLoad = nansen.config.dloc.DataLocationModel(char(filePath));

            testCase.verifyNotEmpty(firstLoad.Data(1).Uuid)
            testCase.verifyEqual(secondLoad.Data(1).Uuid, firstLoad.Data(1).Uuid)
        end

        function testRefreshedFunctionNamesReachTheFile(testCase)
            filePath = testCase.createSettledModel("json");

            function S = renameFirstFunction(S)
                S.Data.MetaDataDef(1).FunctionName = 'otherProject.datalocation.getSubjectId';
            end
            testCase.modifyJsonFile(filePath, @renameFirstFunction)

            nansen.config.dloc.DataLocationModel(char(filePath));

            stored = jsondecode(fileread(filePath));
            expected = sprintf('%s.datalocation.getSubjectId', nansen.getCurrentProject().Name);
            testCase.verifyEqual(stored.Data.MetaDataDef(1).FunctionName, expected)
        end
    end
end
