classdef FileAdapterRegistryTest < matlab.unittest.TestCase
%FileAdapterRegistryTest Phase 2 acceptance tests for the file adapter registry.
%
%   Verifies: sidecar parsing, compat discovery, registry API, legacy struct
%   shape, DataType property contract, and integration shims.

    properties (Constant)
        SidecarRoot = fullfile(fileparts(fileparts(fileparts(fileparts( ...
            fileparts(mfilename('fullpath')))))), 'code', '+nansen', '+dataio', '+fileadapter')
    end

    % ------------------------------------------------------------------ %
    methods (TestClassSetup)
        function addNansenPath(testCase) %#ok<MANU>
            root = fullfile(fileparts(fileparts(fileparts(fileparts( ...
                fileparts(mfilename('fullpath')))))));
            addpath(genpath(fullfile(root, 'code')));
            addpath(genpath(fullfile(root, 'tests')));
        end
    end

    % ------------------------------------------------------------------ %
    % Sidecar parsing
    % ------------------------------------------------------------------ %
    methods (Test)

        function testNumpySidecarParses(testCase)
            filePath = fullfile(testCase.SidecarRoot, 'fileadapter.plugin.json');
            testCase.assertNotEmpty(filePath)
            specs = nansen.plugin.fileadapter.FileAdapterSpec.fromJsonFile(filePath);
            testCase.verifyEqual(numel(specs), 1)
            testCase.verifyEqual(char(specs.Id), 'nansen.dataio.fileadapter.numpy')
            testCase.verifyEqual(char(specs.DataType), 'struct')
            testCase.verifyEqual(cellstr(specs.SupportedFileTypes), {'npy'})
        end

        function testImageStackSidecarParses(testCase)
            filePath = fullfile(testCase.SidecarRoot, '+imagestack', 'fileadapter.plugin.json');
            specs = nansen.plugin.fileadapter.FileAdapterSpec.fromJsonFile(filePath);
            testCase.verifyEqual(numel(specs), 1)
            testCase.verifyEqual(char(specs.Id), 'nansen.dataio.fileadapter.imagestack.ImageStack')
            testCase.verifyEqual(char(specs.DataType), 'ImageStack')
            testCase.verifyTrue(ismember('tif', specs.SupportedFileTypes))
        end

        function testGroupedRoiSidecarParses(testCase)
            % Grouped sidecar (plugins array) must yield one spec per entry
            filePath = fullfile(testCase.SidecarRoot, '+roi', 'fileadapter.plugin.json');
            specs = nansen.plugin.fileadapter.FileAdapterSpec.fromJsonFile(filePath);
            testCase.verifyEqual(numel(specs), 2)
            ids = string({specs.Id});
            testCase.verifyTrue(ismember('nansen.dataio.fileadapter.roi.RoiArray', ids))
            testCase.verifyTrue(ismember('nansen.dataio.fileadapter.roi.RoiGroup', ids))
        end

        function testGroupedTimeseriesSidecarParses(testCase)
            filePath = fullfile(testCase.SidecarRoot, '+timeseries', 'fileadapter.plugin.json');
            specs = nansen.plugin.fileadapter.FileAdapterSpec.fromJsonFile(filePath);
            testCase.verifyEqual(numel(specs), 2)
        end

        function testMissingSupportedTypesThrows(testCase)
            % A sidecar without match.extensions must fail RequiredProperties
            S = struct('id', 'bad.adapter', 'displayName', 'Bad', ...
                'implementation', struct('kind', 'class', 'entrypoint', 'x'), ...
                'outputs', struct('dataType', 'struct'));
            testCase.verifyError( ...
                @() nansen.plugin.fileadapter.FileAdapterSpec.fromSidecarStruct(S), ...
                'NANSEN:Specification:MissingRequiredProperties')
        end

    end

    % ------------------------------------------------------------------ %
    % Registry list & resolve
    % ------------------------------------------------------------------ %
    methods (Test)

        function testRegistryListReturnsNonEmpty(testCase)
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            specs = registry.list();
            testCase.verifyGreaterThan(numel(specs), 0)
        end

        function testDefaultAdapterPresent(testCase)
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            spec = registry.resolve('Default');
            testCase.verifyEqual(char(spec.Id), 'Default')
            testCase.verifyEqual(char(spec.Source), 'builtin')
        end

        function testResolveByStableId(testCase)
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            spec = registry.resolve('nansen.dataio.fileadapter.imagestack.ImageStack');
            testCase.verifyEqual(char(spec.DataType), 'ImageStack')
        end

        function testFindByDisplayName(testCase)
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            specs = registry.findByDisplayName('ImageStack');
            testCase.verifyGreaterThan(numel(specs), 0)
        end

        function testFindByNameFallsBackToDisplayName(testCase)
            % 'ImageStack' is the DisplayName, not the stable Id
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            spec = registry.findByName('ImageStack');
            testCase.verifyEqual(char(spec.DataType), 'ImageStack')
        end

        function testFindByNameUnknownThrows(testCase)
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            testCase.verifyError( ...
                @() registry.findByName('NoSuchAdapter_xyz'), ...
                'nansen:plugin:fileadapter:Registry:NotFound')
        end

        function testNoValidationIssues(testCase)
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            issues = registry.validate();
            errorIssues = issues(strcmp({issues.Severity}, 'error'));
            testCase.verifyEmpty(errorIssues, ...
                sprintf('%d error-level validation issues found', numel(errorIssues)))
        end

    end

    % ------------------------------------------------------------------ %
    % Legacy struct (listFileAdapters compatibility)
    % ------------------------------------------------------------------ %
    methods (Test)

        function testLegacyStructHasExpectedFields(testCase)
            registry = nansen.plugin.fileadapter.Registry.getInstance();
            entries = registry.listLegacy();
            testCase.verifyTrue(isfield(entries, 'FileAdapterName'))
            testCase.verifyTrue(isfield(entries, 'FunctionName'))
            testCase.verifyTrue(isfield(entries, 'SupportedFileTypes'))
            testCase.verifyTrue(isfield(entries, 'DataType'))
        end

        function testListFileAdaptersWrapperReturnsAdapters(testCase)
            adapters = nansen.dataio.listFileAdapters();
            testCase.verifyGreaterThan(numel(adapters), 0)
            testCase.verifyTrue(isfield(adapters, 'FileAdapterName'))
        end

        function testListFileAdaptersFiltersByExtension(testCase)
            adapters = nansen.dataio.listFileAdapters('tif');
            for i = 1:numel(adapters)
                supported = adapters(i).SupportedFileTypes;
                testCase.verifyTrue( ...
                    any(strcmpi('tif', supported)) || strcmp(adapters(i).FileAdapterName, 'N/A'))
            end
        end

    end

    % ------------------------------------------------------------------ %
    % DataType property contract
    % ------------------------------------------------------------------ %
    methods (Test)

        function testDataTypeIsNotConstantOnImageStack(testCase)
            mc = meta.class.fromName('nansen.dataio.fileadapter.imagestack.ImageStack');
            testCase.assumeNotEmpty(mc)
            isProp = strcmp({mc.PropertyList.Name}, 'DataType');
            testCase.verifyTrue(any(isProp), 'DataType property not found')
            prop = mc.PropertyList(isProp);
            testCase.verifyFalse(prop.Constant, ...
                'DataType must not be Constant — it was changed to SetAccess=protected')
            testCase.verifyEqual(prop.SetAccess, 'protected')
        end

        function testDataTypeIsNotConstantOnFunctionFileAdapter(testCase)
            mc = meta.class.fromName('nansen.plugin.fileadapter.FunctionFileAdapter');
            testCase.assumeNotEmpty(mc)
            isProp = strcmp({mc.PropertyList.Name}, 'DataType');
            prop = mc.PropertyList(isProp);
            testCase.verifyFalse(prop.Constant)
        end

    end

    % ------------------------------------------------------------------ %
    % Disabled-state isolation
    % ------------------------------------------------------------------ %
    methods (Test)

        function testDisableAndEnablePlugin(testCase)
            tmpDir = tempname();
            mkdir(tmpDir)
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

            registry = nansen.plugin.fileadapter.Registry.getInstance(tmpDir);
            specs = registry.list();
            testCase.assumeGreaterThan(numel(specs), 1)

            targetId = specs(2).Id; % Skip Default at index 1
            registry.disable(targetId);
            testCase.verifyFalse(registry.isEnabled(targetId))

            listIds = string({registry.list().Id});
            testCase.verifyFalse(ismember(targetId, listIds))

            registry.enable(targetId);
            testCase.verifyTrue(registry.isEnabled(targetId))
        end

        function testDisabledStateIsolatedByProject(testCase)
            tmpA = tempname(); mkdir(tmpA)
            tmpB = tempname(); mkdir(tmpB)
            cleanupA = onCleanup(@() rmdir(tmpA, 's'));
            cleanupB = onCleanup(@() rmdir(tmpB, 's'));

            regA = nansen.plugin.fileadapter.Registry.getInstance(tmpA);
            specsA = regA.list();
            testCase.assumeGreaterThan(numel(specsA), 1)
            targetId = specsA(2).Id;

            regA.disable(targetId);
            testCase.verifyFalse(regA.isEnabled(targetId))

            regB = nansen.plugin.fileadapter.Registry.getInstance(tmpB);
            testCase.verifyTrue(regB.isEnabled(targetId), ...
                'Disabling in project A must not affect project B')
        end

    end

end
