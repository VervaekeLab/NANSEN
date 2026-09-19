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

        function sessionId = sessionIdOf(~, rule, sessionFolder, numLevels)
        %sessionIdOf Run a converted Session ID rule the way NANSEN does
            joinedNames = nansen.config.dloc.DataLocationModel.combineFolderNamesFromPath( ...
                sessionFolder, rule.SubfolderLevel, numLevels, rule.Separator);
            sessionId = nansen.config.dloc.DataLocationModel.applyExtractionPattern( ...
                joinedNames, rule.StringDetectMode, rule.StringDetectInput);
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

        function testVariableWithoutPatternDescriptionHasEmptyDescription(testCase)
            testCase.verifyEqual(testCase.Variables.Description, '')
        end

        function testPatternDescriptionBecomesVariableDescription(testCase)
            fixture = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                '+fixture', 'datasetstructure', 'garad-2022.json');
            dsm = jsondecode(fileread(fixture));
            description = "One repetition of the excitability protocol, membrane potential in mV";
            dsm.dataLocations.filesystemSource.entityLayout(1).filePatterns.description = description;

            [~, variables] = nansen.config.dloc.dsm2DataLocationModel(dsm);

            testCase.verifyEqual(variables.Description, char(description))
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
            convert = @(p) nansen.config.dloc.dsmconversion.convertFilePatternToWildcard( ...
                p, ["recording_id", "cell_id"]);

            [expression, fileType, isConverted, isApproximate] = convert("^{recording_id}_meta\.json$");
            testCase.verifyTrue(isConverted)
            testCase.verifyFalse(isApproximate)
            testCase.verifyEqual(expression, "^*_meta.json$")
            testCase.verifyEqual(fileType, ".json")

            [expression, ~, isConverted] = convert("^{cell_id}_{recording_id}\.ABF$");
            testCase.verifyTrue(isConverted, 'A token naming an ancestor identity becomes * too.')
            testCase.verifyEqual(expression, "^*_*.ABF$")

            [~, ~, isConverted] = convert("^{other_id}\.ABF$");
            testCase.verifyFalse(isConverted, 'Tokens naming other fields have no wildcard equivalent.')

            [expression, ~, ~, isApproximate] = convert("^.*\.ABF$");
            testCase.verifyEqual(expression, "^*.ABF$")
            testCase.verifyFalse(isApproximate, '.* is any text, as * is.')
        end

        function testCharacterClassesAreApproximated(testCase)
            % NANSEN passes the expression to dir, whose only wildcard is *.
            convert = @(p) nansen.config.dloc.dsmconversion.convertFilePatternToWildcard(p, "session_id");
            cases = { ...
                "^TT\d+\.ntt$", "^TT*.ntt$"; ...
                "_ch\d+_\d+\.dat$", "_ch*_*.dat$"; ...
                "_feature_[A-Za-z0-9]+\.fd$", "_feature_*.fd$"; ...
                "_{session_id}__\d{4}-\d{2}-\d{2}\.pkl$", "_*__*-*-*.pkl$"; ...
                "^{session_id}\.eeg\d?$", "^*.eeg*$"};
            for i = 1:height(cases)
                [expression, ~, isConverted, isApproximate] = convert(cases{i, 1});
                testCase.verifyTrue(isConverted, cases{i, 1})
                testCase.verifyTrue(isApproximate, cases{i, 1})
                testCase.verifyEqual(expression, cases{i, 2}, cases{i, 1})
            end
        end

        function testApproximationMatchingEveryFileIsRefused(testCase)
            [expression, ~, isConverted] = nansen.config.dloc.dsmconversion.convertFilePatternToWildcard( ...
                "^{session_id}\.\d$", "session_id");
            testCase.verifyFalse(isConverted, '^*.*$ would match every file in the folder.')
            testCase.verifyEqual(expression, "")
        end

        function testRepeatedPatternNamesAreQualifiedByLocation(testCase)
            % A file pattern name is unique within a level, but a NANSEN
            % variable name is unique within a project. Two locations that
            % hold the same recording in two formats both name their
            % pattern "original".
            [~, variables, report] = nansen.config.dloc.dsm2DataLocationModel( ...
                jsondecode(twoFormatModel()));

            names = string({variables.VariableName});
            testCase.verifyEqual(sort(names), ["igor_original", "notes", "nwb_original"])
            testCase.verifyEqual(variables(names == "igor_original").DataLocation, 'igor')
            testCase.verifyEqual(variables(names == "nwb_original").FileNameExpression, '.nwb$')
            testCase.verifyTrue(any(contains(report.Element, "variables[original]")))
            testCase.verifyFalse(any(contains(report.Element, "variables[notes]")), ...
                'A name used in one location keeps its name.')
        end

        function testCompositeSessionIdJoinsLevelNames(testCase)
            % Day numbers restart in each experiment, so a scanning day is
            % identified by the experiment and the day, within its monkey.
            [dataLocations, ~, report] = nansen.config.dloc.dsm2DataLocationModel( ...
                jsondecode(scanningDayModel()), SessionEntity="scanning_day");
            association = dataLocations(strcmp({dataLocations.Name}, 'association'));

            rule = association.MetaDataDef(strcmp({association.MetaDataDef.VariableName}, 'Session ID'));
            testCase.verifyEqual(rule.SubfolderLevel, [1 2 3], ...
                'The experiment level, the monkey level (an ancestor) and the day level.')
            testCase.verifyEqual(rule.Separator, '_')

            sessionId = testCase.sessionIdOf(rule, '/data/association/PRE_stim/m1/d1', 3);
            testCase.verifyEqual(sessionId, 'PRE_stim_m1_d1')
            testCase.verifyTrue(any(contains(report.Reason, "the Session ID joins the names of levels")))
            testCase.verifyFalse(any(contains(report.Reason, "NANSEN needs a single id field")))
        end

        function testFixedPartOfCompositeIdentityIsLeftOut(testCase)
            % The localizer has no experiment level; a fixed rule gives the
            % experiment, and the Session ID is made of the other levels.
            [dataLocations, ~, report] = nansen.config.dloc.dsm2DataLocationModel( ...
                jsondecode(scanningDayModel()), SessionEntity="scanning_day");
            localizer = dataLocations(strcmp({dataLocations.Name}, 'localizer'));

            rule = localizer.MetaDataDef(strcmp({localizer.MetaDataDef.VariableName}, 'Session ID'));
            testCase.verifyEqual(rule.SubfolderLevel, [1 2])
            testCase.verifyEqual(testCase.sessionIdOf(rule, '/data/localizer/m2/d1', 2), 'm2_d1')
            testCase.verifyTrue(any(contains(report.Element, "dataLocations[localizer].metadataMapping[experiment]")))
        end

        function testUnreadablePartOfCompositeIdentityIsReportedOnce(testCase)
            % Without a rule for the experiment, the Session ID is left
            % unset, and the report gives that reason only
            model = replace(scanningDayModel(), '"metadataRef":"experiment"', '"metadataRef":"protocol"');

            [~, ~, report] = nansen.config.dloc.dsm2DataLocationModel(jsondecode(model), ...
                SessionEntity="scanning_day");

            isAssociation = startsWith(report.Element, "dataLocations[association]");
            testCase.verifyTrue(any(isAssociation & contains(report.Reason, "No extraction rule for this part")))
            testCase.verifyFalse(any(contains(report.Reason, "NANSEN needs a single id field")))
        end
    end
end

function text = scanningDayModel()
%scanningDayModel Scanning days of monkeys in two experiments, numbered from 1 in each
    mapping = @(key, extraction) struct('metadataRef', key, 'extraction', extraction);
    fromLevel = @(method, pattern, level) struct('method', method, 'pattern', pattern, 'entityLayoutLevel', level);
    level = @(name, entityType, pattern) struct('name', name, 'entityType', entityType, 'matchPattern', pattern);
    location = @(name, layout, rules) struct( ...
        'identifier', name, 'displayName', name, 'dataCategory', 'raw', 'sourceType', 'filesystem', ...
        'filesystemSource', struct( ...
            'rootStoragePaths', {{struct('identifier', 'main', 'path', ['/data/' name])}}, ...
            'entityLayout', {layout}, 'metadataMapping', {rules}));
    dayRules = {mapping('subject_id', fromLevel('substring', ':', 'monkeys')), ...
                mapping('day_number', fromLevel('regex', '^d(\d+)$', 'days'))};
    association = location('association', ...
        {struct('name', 'experiments', 'matchPattern', '^(PRE|POST)_stim$'), ...
         level('monkeys', 'subject', '^m\d+$'), level('days', 'scanning_day', '^d\d+$')}, ...
        [{mapping('experiment', fromLevel('substring', ':', 'experiments'))}, dayRules]);
    localizer = location('localizer', ...
        {level('monkeys', 'subject', '^m\d+$'), level('days', 'scanning_day', '^d\d+$')}, ...
        [{mapping('experiment', struct('method', 'fixed', 'value', 'localizer'))}, dayRules]);
    model = struct( ...
        'schemaVersion', '0.1.0', ...
        'entityTypes', {{struct('name', 'subject', 'identifierRef', 'subject_id'), ...
                         struct('name', 'scanning_day', 'identifierRefs', {{'experiment'; 'day_number'}})}}, ...
        'metadataDefinitions', struct( ...
            'subject_id', struct('name', 'subject_id', 'dataType', 'string', 'ofEntity', 'subject'), ...
            'experiment', struct('name', 'experiment', 'dataType', 'string', 'ofEntity', 'scanning_day'), ...
            'day_number', struct('name', 'day_number', 'dataType', 'integer', 'ofEntity', 'scanning_day')), ...
        'dataLocations', {{association, localizer}});
    text = jsonencode(model);
end

function text = twoFormatModel()
%twoFormatModel A cell folder per location, the recording as Igor Pro in one and NWB in the other
    location = @(name, extension, extraPattern) struct( ...
        'identifier', name, 'displayName', name, 'dataCategory', 'raw', 'sourceType', 'filesystem', ...
        'filesystemSource', struct( ...
            'rootStoragePaths', {{struct('identifier', 'main', 'path', ['/data/' name])}}, ...
            'entityLayout', {{struct('name', 'cells', 'entityType', 'cell', 'matchPattern', '^cell\d+$', ...
                'filePatterns', {[{struct('name', 'original', 'pattern', ['\.' extension '$'])}, extraPattern]})}}, ...
            'metadataMapping', {{struct('metadataRef', 'cell_id', ...
                'extraction', struct('method', 'substring', 'pattern', ':', 'entityLayoutLevel', 'cells'))}}));
    model = struct( ...
        'schemaVersion', '0.1.0', ...
        'entityTypes', {{struct('name', 'cell', 'identifierRef', 'cell_id')}}, ...
        'metadataDefinitions', struct('cell_id', struct('name', 'cell_id', 'dataType', 'string', 'ofEntity', 'cell')), ...
        'dataLocations', {{location('igor', 'pxp', {}), ...
                           location('nwb', 'nwb', {struct('name', 'notes', 'pattern', '\.txt$')})}});
    text = jsonencode(model);
end
