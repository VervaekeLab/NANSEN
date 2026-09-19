classdef Dsm2DataLocationFilesBelowSessionTest < matlab.unittest.TestCase
%Dsm2DataLocationFilesBelowSessionTest - File patterns on layout levels below the session
%
%   Uses a model of monkey folders with a folder per scanning day (the
%   session), a folder named funct in each day, and run files in it with
%   the file patterns bold (.nii.gz) and sidecar (.json).
%
%   Run tests:
%       runtests('nansen.unittest.config.Dsm2DataLocationFilesBelowSessionTest')

    properties
        Model
    end

    methods (TestClassSetup)
        function loadModel(testCase)
            fixture = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                '+fixture', 'datasetstructure', 'runs-below-session.json');
            testCase.Model = jsondecode(fileread(fixture));
        end
    end

    methods (Test)
        function testFilePatternsInFixedFolderBecomeVariables(testCase)
            [~, variables] = nansen.config.dloc.dsm2DataLocationModel(testCase.Model);

            testCase.verifyEqual(sort(string({variables.VariableName})), ["bold", "sidecar"])
            testCase.verifyEqual(string({variables.Subfolder}), ["funct", "funct"])
        end

        function testExtensionOfSeveralPartsIsFileType(testCase)
            [~, variables] = nansen.config.dloc.dsm2DataLocationModel(testCase.Model);

            bold = variables(strcmp({variables.VariableName}, 'bold'));
            testCase.verifyEqual(bold.FileType, '.nii.gz')
            testCase.verifyEqual(bold.Description, 'Functional run, NIfTI')
        end

        function testNameInSessionAndFixedFolderIsQualifiedBySubfolder(testCase)
            % A sidecar file in the day folder and one in its funct folder
            model = testCase.Model;
            model.dataLocations.filesystemSource.entityLayout{2}.filePatterns = ...
                {struct('name', 'sidecar', 'pattern', '_day\.json$')};

            [~, variables, report] = nansen.config.dloc.dsm2DataLocationModel(model);

            names = string({variables.VariableName});
            testCase.verifyEqual(sort(names), ["bold", "funct_sidecar", "sidecar"])
            testCase.verifyEqual(variables(names == "funct_sidecar").Subfolder, 'funct')
            testCase.verifyEmpty(variables(names == "sidecar").Subfolder)
            testCase.verifyTrue(any(contains(report.Element, "variables[sidecar]")))
        end

        function testNameInNestedFixedFoldersIsQualifiedBySubfolder(testCase)
            % funct/ and funct/raw/ each hold a NIfTI file
            model = testCase.Model;
            layout = model.dataLocations.filesystemSource.entityLayout(:);
            nifti = {struct('name', 'nifti', 'pattern', '\.nii$')};
            layout{3}.filePatterns = nifti;
            raw = struct('name', 'raw-folder', 'isVariable', false, 'fixedName', 'raw', 'filePatterns', {nifti});
            model.dataLocations.filesystemSource.entityLayout = [layout(1:3); {raw}; layout(4:end)];

            [~, variables] = nansen.config.dloc.dsm2DataLocationModel(model);

            names = string({variables.VariableName});
            testCase.verifyEqual(sort(names(contains(names, "nifti"))), ["funct_nifti", "funct_raw_nifti"])
            testCase.verifyEqual(variables(names == "funct_raw_nifti").Subfolder, 'funct/raw')
        end

        function testSeveralFilesPerSessionIsReported(testCase)
            [~, ~, report] = nansen.config.dloc.dsm2DataLocationModel(testCase.Model);

            isRunLevel = endsWith(report.Element, "entityLayout[run-files]");
            testCase.verifyTrue(any(isRunLevel & contains(report.Reason, "uses the first")))
        end

        function testLevelsBelowVariableFolderAreDropped(testCase)
            model = testCase.Model;
            layout = model.dataLocations.filesystemSource.entityLayout;
            layout{3} = struct('name', 'protocol-folders', 'matchPattern', '^[a-z]+$');
            model.dataLocations.filesystemSource.entityLayout = layout;

            [~, variables, report] = nansen.config.dloc.dsm2DataLocationModel(model);

            testCase.verifyEmpty(variables)
            testCase.verifyTrue(any(endsWith(report.Element, "entityLayout[run-files]") ...
                & contains(report.Reason, "dropped")))
        end
    end
end
