classdef ModuleActivationTest < matlab.unittest.TestCase
%ModuleActivationTest The two-photon module is discovered and lists its items
%
%   Characterization test for module activation. It pins what NANSEN's
%   module discovery finds for the two-photon module: the module itself,
%   its session methods, file adapters, data variables and data locations.
%
%   This is the migration's final gate in miniature: it must pass with the
%   module inside NANSEN and, after extraction, with the module's code
%   folder on the path next to a NANSEN installation.
%
%   Run tests:
%       runtests('twophotontest.ModuleActivationTest')

    properties (Constant, Access = private)
        ExpectedSessionMethods = sort([ ...
            "deltaFOverF", "imageStack", "meanFluorescence", ...
            "twoPhotonMotionCorrected", "twoPhotonRawImages", ...
            "plotImageStats", ...
            "EXTRACT", "FluFinder", "Quicky", "suite2p", ...
            "Caiman", ...
            "DenoiseStack", "DownsampleStack", ...
            "flowreg", "normcorre", ...
            "openRoiClassifier", "openRoiManager", ...
            "classifyMultiSessionRois", "computeClassificationData", ...
            "editRois", "migrateRoisToFovs", ...
            "SelectRoiForSignalExtraction", "computeDff", ...
            "extractSignals", "extractSignalsMultiChannel"])

        ExpectedFileAdapters = sort([ ...
            "ChiatahDemoFile", "RoiGroup", "RoiSignalArray", ...
            "ScanImageMultiRoi2PSeries", "SciScanXYTSeries"])

        ExpectedDataVariables = sort([ ...
            "RoiSignals_Deconvolved", "RoiSignals_Denoised", ...
            "RoiSignals_Dff", "RoiSignals_MeanF", "RoiSignals_NeuropilF", ...
            "Rois", "RoisCurated", ...
            "TwoPhotonSeries_Corrected", "TwoPhotonSeries_Original"])

        ExpectedDataLocations = "SciScan 2P"
    end

    properties (Access = private)
        Module nansen.module.Module
    end

    methods (TestClassSetup)
        function createModule(testCase)
            moduleEntry = twophotontest.helper.findModuleEntry();
            testCase.Module = nansen.module.Module(moduleEntry.FolderPath);
        end
    end

    methods (Test)

        function testModuleIsDiscovered(testCase)
            moduleEntry = twophotontest.helper.findModuleEntry();
            testCase.verifyEqual(string(moduleEntry.ShortName), "twophoton")
            testCase.verifyFalse(moduleEntry.isCoreModule)
            testCase.verifyTrue(isfolder(moduleEntry.FolderPath))
            testCase.verifyTrue(isfile(moduleEntry.RequirementManifestPath), ...
                'The module should ship a dependency manifest')
        end

        function testSessionMethodsAreListed(testCase)
            itemTable = testCase.Module.getTable('SessionMethod');
            testCase.verifyEqual(sort(string(itemTable.Name))', ...
                testCase.ExpectedSessionMethods)
            testCase.verifyTrue(all(startsWith(string(itemTable.FunctionName), ...
                twophotontest.helper.modulePackageName() + ".sessionmethod.")))
        end

        function testFileAdaptersAreListed(testCase)
            itemTable = testCase.Module.getTable('FileAdapter');
            testCase.verifyEqual(sort(string(itemTable.FileAdapterName))', ...
                testCase.ExpectedFileAdapters)
            testCase.verifyTrue(all(startsWith(string(itemTable.FunctionName), ...
                twophotontest.helper.modulePackageName() + ".fileadapter.")))
        end

        function testDataVariablesAreListed(testCase)
            itemTable = testCase.Module.getTable('DataVariables');
            testCase.verifyEqual(sort(string(itemTable.VariableName))', ...
                testCase.ExpectedDataVariables)
        end

        function testDataLocationsAreListed(testCase)
            itemTable = testCase.Module.getTable('DataLocations');
            testCase.verifyEqual(string(itemTable.Name)', ...
                testCase.ExpectedDataLocations)
        end
    end
end
