classdef ModuleSpecTest < matlab.unittest.TestCase
%ModuleSpecTest Tests for NANSEN module manifest parsing.

    methods (Test)
        function testFromJsonFileReadsSpecificationEnvelope(testCase)
        %testFromJsonFileReadsSpecificationEnvelope Reads module.nansen.json.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            manifestPath = fullfile(F.Folder, 'module.nansen.json');
            testCase.writeManifest(manifestPath, "Example", "Example module");

            spec = nansen.module.ModuleSpec.fromJsonFile(manifestPath);

            testCase.verifyEqual(spec.Name, "Example")
            testCase.verifyEqual(spec.Description, "Example module")
        end

        function testModuleReadsConfigurationViaModuleSpec(testCase)
        %testModuleReadsConfigurationViaModuleSpec Module consumes ModuleSpec.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            F = testCase.applyFixture(TemporaryFolderFixture);

            manifestPath = fullfile(F.Folder, 'module.nansen.json');
            testCase.writeManifest(manifestPath, "Runtime Module", "Runtime description");

            module = nansen.module.Module(F.Folder);

            testCase.verifyEqual(module.Name, "Runtime Module")
            testCase.verifyEqual(module.Description, "Runtime description")
        end

        function testMissingNameErrors(testCase)
        %testMissingNameErrors Required module fields are validated.
            S = struct('Description', "No name");

            testCase.verifyError( ...
                @() nansen.module.ModuleSpec.fromStruct(S), ...
                'NANSEN:Specification:MissingRequiredProperties')
        end
    end

    methods (Access = private)
        function writeManifest(~, filePath, name, description)
        %writeManifest Write a minimal module.nansen.json fixture.
            S = struct( ...
                'x_type',        'NANSEN Module Specification', ...
                'x_description', 'Contains properties for a NANSEN module', ...
                'x_version',     '1.0.0', ...
                'Properties',    struct( ...
                    'Name',        char(name), ...
                    'Description', char(description)));

            jsonText = jsonencode(S, 'PrettyPrint', true);
            jsonText = strrep(jsonText, '"x_type"', '"_type"');
            jsonText = strrep(jsonText, '"x_description"', '"_description"');
            jsonText = strrep(jsonText, '"x_version"', '"_version"');

            fid = fopen(filePath, 'w', 'n', 'UTF-8');
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonText);
        end
    end
end
