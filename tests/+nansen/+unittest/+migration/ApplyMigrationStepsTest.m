classdef ApplyMigrationStepsTest < matlab.unittest.TestCase
%ApplyMigrationStepsTest Tests for running numbered migration steps in order
%
%   The steps are test doubles that note when they run, so that the order
%   of steps and of the recorded versions can be checked without any data
%   on disk.
%
%   Run tests:
%       runtests('nansen.unittest.migration.ApplyMigrationStepsTest')

    properties
        Events (1,:) string = strings(1, 0)
    end

    methods (Test)

        function testNoStepsDoesNothing(testCase)
            nansen.internal.migration.applyMigrationSteps(1, testCase.createSteps([]), @testCase.noteRecorded)

            testCase.verifyEmpty(testCase.Events)
        end

        function testDataAtTheLatestVersionRunsNothing(testCase)
            nansen.internal.migration.applyMigrationSteps(4, testCase.createSteps(2:4), @testCase.noteRecorded)

            testCase.verifyEmpty(testCase.Events)
        end

        function testOnlyMissingStepsRun(testCase)
            nansen.internal.migration.applyMigrationSteps(3, testCase.createSteps(2:4), @testCase.noteRecorded)

            testCase.verifyEqual(testCase.Events, ["apply 4", "record 4"])
        end

        function testSeveralMissedStepsRunInOrder(testCase)
        % Someone who skipped updates must pass through every step between

            nansen.internal.migration.applyMigrationSteps(1, testCase.createSteps(2:4), @testCase.noteRecorded)

            testCase.verifyEqual(testCase.Events, ...
                ["apply 2", "record 2", "apply 3", "record 3", "apply 4", "record 4"])
        end

        function testFailedStepStopsTheChain(testCase)
        % The version stays at the last step that finished

            steps = testCase.createSteps(2:4);
            steps(2).Apply = @() error('Test:StepProblem', 'The step failed.');

            testCase.verifyError( ...
                @() nansen.internal.migration.applyMigrationSteps(1, steps, @testCase.noteRecorded), ...
                'NANSEN:Migration:StepFailed')

            testCase.verifyEqual(testCase.Events, ["apply 2", "record 2"])
        end

        function testFailedStepKeepsItsCause(testCase)
            steps = testCase.createSteps(2);
            steps(1).Apply = @() error('Test:StepProblem', 'The step failed.');

            try
                nansen.internal.migration.applyMigrationSteps(1, steps, @testCase.noteRecorded)
                testCase.verifyFail('The failed step should have thrown an error.')
            catch ME
                testCase.verifyEqual(ME.identifier, 'NANSEN:Migration:StepFailed')
                testCase.verifyEqual(ME.cause{1}.identifier, 'Test:StepProblem')
            end
        end

        function testChainResumesAfterTheLastFinishedStep(testCase)
            nansen.internal.migration.applyMigrationSteps(2, testCase.createSteps(2:4), @testCase.noteRecorded)

            testCase.verifyEqual(testCase.Events, ["apply 3", "record 3", "apply 4", "record 4"])
        end

        function testGapInVersionsIsRejected(testCase)
            testCase.verifyError( ...
                @() nansen.internal.migration.applyMigrationSteps(1, testCase.createSteps([2, 4]), @testCase.noteRecorded), ...
                'NANSEN:Migration:InvalidSteps')

            testCase.verifyEmpty(testCase.Events)
        end

        function testVersionsOutOfOrderAreRejected(testCase)
            testCase.verifyError( ...
                @() nansen.internal.migration.applyMigrationSteps(1, testCase.createSteps([3, 2]), @testCase.noteRecorded), ...
                'NANSEN:Migration:InvalidSteps')
        end
    end

    methods (Access = private)

        function steps = createSteps(testCase, versions)
        %createSteps Create steps that note the moment they run

            steps = struct('Version', {}, 'Description', {}, 'Apply', {});

            for i = 1:numel(versions)
                steps(i).Version = versions(i);
                steps(i).Description = "step " + versions(i);
                steps(i).Apply = @() testCase.noteApplied(versions(i));
            end
        end

        function noteApplied(testCase, stepVersion)
            testCase.Events(end+1) = "apply " + stepVersion;
        end

        function noteRecorded(testCase, stepVersion)
            testCase.Events(end+1) = "record " + stepVersion;
        end
    end
end
