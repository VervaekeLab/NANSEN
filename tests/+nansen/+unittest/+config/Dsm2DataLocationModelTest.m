classdef Dsm2DataLocationModelTest < matlab.unittest.TestCase
    %Dsm2DataLocationModelTest Converting a Dataset Structure Model to NANSEN items
    %
    %   Uses the model written for Garad and Lessmann (2022): one flat folder
    %   of ABF files named <yyMMdd>_<slice><repeat>.ABF, a cell entity with no
    %   folder of its own, and a recording entity per file.
    %
    %   Extraction rules are checked by running them through NANSEN's own
    %   extraction, so the tests assert the values NANSEN will produce rather
    %   than the text of the rules.
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.Dsm2DataLocationModelTest')

    properties (Constant)
        FileName = '170518_1a.ABF'
    end

    properties
        DataLocations
        Variables
        Report
    end

    properties (TestParameter)
        regexCase = { ...
            {'^(\d{6}_\d+[a-z])\.ABF$', '170518_1a'}, ...
            {'^(\d{6}_\d+)[a-z]\.ABF$', '170518_1'}, ...
            {'^\d{6}_(\d+)[a-z]\.ABF$', '1'}, ...
            {'^.*_(\d+)[a-z]\.ABF$', '1'}, ...
            {'\.(ABF|abf)$', 'ABF'}, ...
            {'^\d{6}_\d+[a-z]', '170518_1a'}}
        sliceCase = { ...
            {'0:6', '170518'}, {':', '170518_1a.ABF'}, {'9:', '.ABF'}, ...
            {':-4', '170518_1a'}, {'7:-4', '1a'}, {'-3:', 'ABF'}, {'-4:-3', '.'}}
    end

    methods (TestClassSetup)
        function convertGarad(testCase)
            fixture = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                '+fixture', 'datasetstructure', 'garad-2022.json');
            [testCase.DataLocations, testCase.Variables, testCase.Report] = ...
                nansen.config.dloc.dsm2DataLocationModel(fixture);
        end
    end

    methods (Access = private)
        function value = extract(testCase, variableName)
        %extract Run a converted metadata rule on the example file name
            rule = testCase.DataLocations.MetaDataDef( ...
                strcmp({testCase.DataLocations.MetaDataDef.VariableName}, variableName));
            value = nansen.config.dloc.DataLocationModel.applyExtractionPattern( ...
                testCase.FileName, rule.StringDetectMode, rule.StringDetectInput);
        end

        function verifyReported(testCase, elementPart)
            testCase.verifyTrue(any(contains(testCase.Report.Element, elementPart)), ...
                sprintf('Expected the report to mention %s.', elementPart))
        end

        function verifyNotReported(testCase, elementPart)
            testCase.verifyFalse(any(contains(testCase.Report.Element, elementPart)), ...
                sprintf('%s was mapped and should not be in the report.', elementPart))
        end
    end

    methods (Test)

        function testOneReadOnlyLocationOfFiles(testCase)
            dataLocation = testCase.DataLocations;
            testCase.verifyNumElements(dataLocation, 1)
            testCase.verifyEqual(dataLocation.Name, 'garad')
            testCase.verifyEqual(dataLocation.Type.Name, 'recorded')

            level = dataLocation.SubfolderStructure;
            testCase.verifyNumElements(level, 1)
            testCase.verifyEqual(level.Type, 'Session')
            testCase.verifyFalse(level.IsFolder, 'Each recording is a file, not a folder.')
            testCase.verifyEqual(level.Expression, '^\d{6}_\d+[a-z]\.ABF$')
            testCase.verifyEqual(level.IgnoreList, {}, ...
                'Exclude patterns must not become substring ignores; "." would drop every file.')

            testCase.verifyEqual(dataLocation.RootPath.Value, ...
                '/Users/eivihe/Data/ShareBrain/InDepthCuration/garad-2022')
            testCase.verifyEqual(dataLocation.RootPath.DiskType, 'Local')
        end

        function testRecordingIsTheSessionAndCellTheSubject(testCase)
            testCase.verifyEqual(testCase.extract('Session ID'), '170518_1a')
            testCase.verifyEqual(testCase.extract('Subject ID'), '170518_1')
        end

        function testRecordingDateUsesItsFormat(testCase)
            rule = testCase.DataLocations.MetaDataDef( ...
                strcmp({testCase.DataLocations.MetaDataDef.VariableName}, 'Experiment Date'));
            testCase.verifyEqual(rule.StringDetectMode, 'ind')
            testCase.verifyEqual(rule.StringFormat, 'yyMMdd')
            testCase.verifyEqual(testCase.extract('Experiment Date'), '170518')
        end

        function testAbsentTimeIsLeftUnset(testCase)
            rule = testCase.DataLocations.MetaDataDef( ...
                strcmp({testCase.DataLocations.MetaDataDef.VariableName}, 'Experiment Time'));
            testCase.verifyEmpty(rule.SubfolderLevel)
        end

        function testAbfFileBecomesAVariable(testCase)
            variable = testCase.Variables;
            testCase.verifyNumElements(variable, 1)
            testCase.verifyEqual(variable.VariableName, 'abf')
            testCase.verifyEqual(variable.FileNameExpression, '^*.ABF$')
            testCase.verifyEqual(variable.FileType, '.ABF')
            testCase.verifyEqual(variable.DataLocation, 'garad')
            testCase.verifyEqual(variable.DataLocationUuid, testCase.DataLocations.Uuid)
            testCase.verifyEqual(variable.FileAdapter, 'Default', ...
                'NANSEN has no ABF file adapter.')
        end

        function testReportListsWhatWasNotMapped(testCase)
            testCase.verifyReported("metadataDefinitions[slice_number]")
            testCase.verifyReported("metadataDefinitions[protocol_repeat]")
            testCase.verifyReported("entityRelationships")
            testCase.verifyReported("excludePatterns")
            testCase.verifyReported("filePatterns[abf].isRequired")
            testCase.verifyReported("filePatterns[abf].fileAdapter")
        end

        function testReportLeavesOutWhatWasMapped(testCase)
            testCase.verifyNotReported("metadataDefinitions[cell_id]")
            testCase.verifyNotReported("metadataDefinitions[recording_id]")
            testCase.verifyNotReported("metadataDefinitions[recording_date]")
            testCase.verifyNotReported("dataCategory")
            testCase.verifyNotReported("entityTypes[")
        end

        function testSessionEntityWithoutALevelIsReported(testCase)
            % A cell has no folder or file of its own, so NANSEN could not
            % find it on disk as a session.
            fixture = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                '+fixture', 'datasetstructure', 'garad-2022.json');
            [dataLocations, ~, report] = nansen.config.dloc.dsm2DataLocationModel( ...
                fixture, SessionEntity="cell");

            testCase.verifyEmpty(dataLocations)
            testCase.verifyTrue(any(contains(report.Reason, "session entity 'cell'")))
        end

        function testRegexBecomesWholeMatch(testCase, regexCase)
            [pattern, isConverted] = ...
                nansen.config.dloc.dsmconversion.convertRegexToWholeMatch(regexCase{1});
            testCase.assertTrue(isConverted)
            value = nansen.config.dloc.DataLocationModel.applyExtractionPattern( ...
                testCase.FileName, 'expr', char(pattern));
            testCase.verifyEqual(value, regexCase{2})
        end

        function testQuantifiedGroupIsNotConverted(testCase)
            [~, isConverted] = ...
                nansen.config.dloc.dsmconversion.convertRegexToWholeMatch('^(\d)+_');
            testCase.verifyFalse(isConverted)
        end

        function testSliceGivesThePythonValue(testCase, sliceCase)
            [mode, input, isConverted] = ...
                nansen.config.dloc.dsmconversion.convertSliceToExtraction(sliceCase{1});
            testCase.assertTrue(isConverted)
            value = nansen.config.dloc.DataLocationModel.applyExtractionPattern( ...
                testCase.FileName, char(mode), char(input));
            testCase.verifyEqual(value, sliceCase{2})
        end

        function testSliceNeverUsesEndOutsideTheWholeRange(testCase)
            % NANSEN's ind mode accepts end only as 1:end.
            for slice = ["0:6", ":", "9:", ":-4", "7:-4", "-3:"]
                [mode, input] = nansen.config.dloc.dsmconversion.convertSliceToExtraction(slice);
                if mode == "ind"
                    testCase.verifyTrue(~contains(input, "end") || input == "1:end", slice)
                end
            end
        end

        function testFilePatternsBecomeWildcards(testCase)
            convert = @(p) nansen.config.dloc.dsmconversion.convertFilePatternToWildcard(p, "recording_id");

            [expression, fileType, isConverted] = convert("^{recording_id}_meta\.json$");
            testCase.verifyTrue(isConverted)
            testCase.verifyEqual(expression, "^*_meta.json$")
            testCase.verifyEqual(fileType, ".json")

            [~, ~, isConverted] = convert("^{other_id}\.ABF$");
            testCase.verifyFalse(isConverted, 'Only tokens naming the session identity become *.')

            [~, ~, isConverted] = convert("^\d+\.ABF$");
            testCase.verifyFalse(isConverted, '\d has no wildcard equivalent.')
        end
    end
end
