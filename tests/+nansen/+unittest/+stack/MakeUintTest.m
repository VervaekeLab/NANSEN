classdef MakeUintTest < matlab.unittest.TestCase
    %MakeUintTest Unit tests for stack.makeuint8 and stack.makeuint16.
    %
    %   Covers the intensity rescaling shared by makeuint8 and
    %   makeuint16 via their common private helper: explicit vs.
    %   estimated limits, saturation, NaN handling, cropAmount, and two
    %   regressions - a tolerance value that was previously silently
    %   discarded, and an operator-precedence bug in makeuint16 that
    %   scaled to (2^16).*normalized-1 instead of (2^16-1).*normalized.
    %
    %   Run tests:
    %       runtests('nansen.unittest.stack.MakeUintTest')

    properties (TestParameter)
        targetType = struct( ...
            'uint8',  struct('makeFcn', @stack.makeuint8,  'className', 'uint8',  'maxValue', 255), ...
            'uint16', struct('makeFcn', @stack.makeuint16, 'className', 'uint16', 'maxValue', 65535))
    end

    methods (Test)

        % ------------------------------------------------------------
        % Explicit limits - exact linear scaling and saturation
        % ------------------------------------------------------------

        function testExplicitLimitsProduceExactEndpoints(testCase, targetType)
            % Values at 0%, 50%, and 100% of bLims map to the nearest
            % integer fraction of the target class's maximum value.
            % A plain double input also exercises the class-preserving
            % path (previously imArray was unconditionally cast to
            % single, even when it was already double).
            imArray = [0, 50, 100];
            bLims = [0, 100];
            expected = round(targetType.maxValue * [0, 0.5, 1]);

            result = targetType.makeFcn(imArray, bLims);

            testCase.verifyEqual(double(result), expected);
        end

        function testValueBelowLimitsSaturatesToZero(testCase, targetType)
            % A value under minVal saturates to 0 rather than wrapping.
            imArray = single(-1000);
            bLims = [0, 100];

            result = targetType.makeFcn(imArray, bLims);

            testCase.verifyEqual(double(result), 0);
        end

        function testValueAboveLimitsSaturatesToMax(testCase, targetType)
            % A value over maxVal saturates to the class maximum.
            imArray = single(1000);
            bLims = [0, 100];

            result = targetType.makeFcn(imArray, bLims);

            testCase.verifyEqual(double(result), targetType.maxValue);
        end

        % ------------------------------------------------------------
        % Output shape and class
        % ------------------------------------------------------------

        function testOutputPreservesInputSize(testCase, targetType)
            imArray = rand(12, 9, 4);

            result = targetType.makeFcn(imArray);

            testCase.verifySize(result, size(imArray));
        end

        function testOutputClassMatchesFunctionName(testCase, targetType)
            imArray = rand(5, 5);

            result = targetType.makeFcn(imArray);

            testCase.verifyClass(result, targetType.className);
        end

        % ------------------------------------------------------------
        % Data-driven limit estimation
        % ------------------------------------------------------------

        function testNaNValuesAreExcludedFromLimitEstimation(testCase, targetType)
            % A NaN (e.g. from registration padding) must not corrupt
            % the sorted-percentile estimate or appear in the output.
            imArray = single(1:1000);
            imArray(1) = NaN;

            result = targetType.makeFcn(imArray);

            testCase.verifyFalse(any(isnan(double(result))));
        end

        function testCropAmountExcludesBorderFromEstimation(testCase, targetType)
            % A moderate border outlier inflates the estimated maxVal
            % when included, compressing an interior pixel toward the
            % low end of the output range. Cropping the border away
            % lets that same interior pixel reach a higher,
            % uncompressed output value.
            imArray = zeros(20, 20, "single");
            imArray(10, 10) = 100; % interior sample, well clear of the border
            imArray([1, end], :) = 500; % border outlier, moderate (non-saturating)
            imArray(:, [1, end]) = 500;

            resultUncropped = targetType.makeFcn(imArray, [], [], 0);
            resultCropped = targetType.makeFcn(imArray, [], [], 8);

            testCase.verifyGreaterThan( ...
                double(resultCropped(10, 10)), double(resultUncropped(10, 10)));
        end

        % ------------------------------------------------------------
        % Regression: tolerance was previously reset to 0.0005 whenever
        % bLims was empty, regardless of the value the caller passed.
        % ------------------------------------------------------------

        function testCustomToleranceChangesEstimatedLimits(testCase, targetType)
            imArray = single(1:1000);
            imArray(1) = -1e6;
            imArray(end) = 1e6;

            resultDefaultTolerance = targetType.makeFcn(imArray, [], []);
            resultWideTolerance = targetType.makeFcn(imArray, [], 0.05);

            testCase.verifyNotEqual(resultWideTolerance, resultDefaultTolerance);
        end

        function testEmptyToleranceMatchesOmittedTolerance(testCase, targetType)
            imArray = single(1:1000);

            resultOmitted = targetType.makeFcn(imArray);
            resultEmpty = targetType.makeFcn(imArray, [], []);

            testCase.verifyEqual(resultEmpty, resultOmitted);
        end

        % ------------------------------------------------------------
        % Argument validation
        % ------------------------------------------------------------

        function testNegativeCropAmountIsRejected(testCase, targetType)
            imArray = rand(5, 5);

            testCase.verifyError( ...
                @() targetType.makeFcn(imArray, [], [], -1), ...
                'MATLAB:validators:mustBeNonnegative');
        end
    end

    methods (Test)

        % ------------------------------------------------------------
        % Regression: makeuint16 previously computed
        % normalized.*2^16-1 (operator precedence: .* binds tighter
        % than binary -), instead of normalized.*(2^16-1). A midpoint
        % input exposes the roughly one-count error this caused across
        % the range.
        % ------------------------------------------------------------

        function testUint16MidpointRoundsToExactHalfRange(testCase)
            imArray = single(0.5);
            bLims = [0, 1];

            result = stack.makeuint16(imArray, bLims);

            testCase.verifyEqual(double(result), 32768);
        end

        % ------------------------------------------------------------
        % Regression: makeuint8 and makeuint16 now share one helper, so
        % they must agree on relative scaling for the same input.
        % ------------------------------------------------------------

        function testMakeuint8AndMakeuint16AgreeOnRelativeScaling(testCase)
            imArray = single(linspace(0, 1, 50));
            bLims = [0, 1];

            result8 = double(stack.makeuint8(imArray, bLims));
            result16 = double(stack.makeuint16(imArray, bLims));

            testCase.verifyEqual(result16 / 65535, result8 / 255, AbsTol=2/255);
        end
    end
end
