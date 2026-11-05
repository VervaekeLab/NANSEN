classdef DffTest < matlab.unittest.TestCase
%DffTest Pins the numerics of the two-photon dF/F computation
%
%   Characterization tests for nansen.twophoton.roisignals.computeDff and
%   the dF/F methods it dispatches to by name. The expected values are the
%   formulas the methods implement today, so a namespace move that changes
%   a result, or that breaks the by-name method discovery, fails here.
%
%   Run tests:
%       runtests('twophotontest.DffTest')

    properties (Constant, Access = private)
        NumSamples = 200
        NumRois = 3
        AbsTol = 1e-10
    end

    methods (Access = private)

        function signalArray = createRoiSignals(testCase, numSubregions)
        %createRoiSignals Positive fluorescence traces with a transient
            arguments
                testCase
                numSubregions (1,1) double = 1
            end
            rng(42, 'twister')
            numSamples = testCase.NumSamples;
            numRois = testCase.NumRois;

            baseline = 100 + 20*rand(1, 1, numRois);
            noise = 5*randn(numSamples, numSubregions, numRois);
            transient = zeros(numSamples, 1, 1);
            transient(50:80) = 60*exp(-(0:30)/10);

            signalArray = baseline + noise + transient;
        end

        function dff = computeDff(~, signalArray, varargin)
            dff = nansen.twophoton.roisignals.computeDff(signalArray, varargin{:});
        end
    end

    methods (Test)

        function testDefaultParametersListTheThreeMethods(testCase)
            % The method list is discovered from the dff package folder, so
            % it doubles as a check that the package is on the path.
            defaults = nansen.twophoton.roisignals.computeDff();
            testCase.verifyEqual(sort(string(defaults.dffFcn_)), ...
                ["dffChenEtAl2013", "dffClassic", "dffRoiMinusDffNpil"])
            testCase.verifyEqual(string(defaults.dffFcn), "dffClassic")
            testCase.verifyEqual(defaults.baseline, 20)
            testCase.verifyFalse(defaults.correctBaseline)
        end

        function testClassicDffIsPercentileBaselineNormalised(testCase)
            signalArray = testCase.createRoiSignals();
            dff = testCase.computeDff(signalArray);

            fRoi = squeeze(signalArray(:, 1, :));
            fRoi0 = prctile(fRoi, 20, 1);
            expected = (fRoi - fRoi0) ./ fRoi0;

            testCase.verifySize(dff, [testCase.NumSamples, testCase.NumRois])
            testCase.verifyEqual(dff, expected, 'AbsTol', testCase.AbsTol)
        end

        function testBaselinePercentileIsHonoured(testCase)
            signalArray = testCase.createRoiSignals();
            dff = testCase.computeDff(signalArray, 'baseline', 50);

            fRoi = squeeze(signalArray(:, 1, :));
            fRoi0 = prctile(fRoi, 50, 1);
            expected = (fRoi - fRoi0) ./ fRoi0;

            testCase.verifyEqual(dff, expected, 'AbsTol', testCase.AbsTol)
        end

        function testChenDffSubtractsWeightedNeuropil(testCase)
            signalArray = testCase.createRoiSignals(2);
            dff = testCase.computeDff(signalArray, 'dffFcn', 'dffChenEtAl2013');

            fRoi = squeeze(signalArray(:, 1, :));
            fPil = squeeze(signalArray(:, 2, :));
            fTrue = fRoi - 0.7*fPil + prctile(fPil, 20);
            fTrue0 = prctile(fTrue, 20);
            expected = (fTrue - fTrue0) ./ fTrue0;

            testCase.verifySize(dff, [testCase.NumSamples, testCase.NumRois])
            testCase.verifyEqual(dff, expected, 'AbsTol', testCase.AbsTol)
        end

        function testRoiMinusNeuropilDffRuns(testCase)
            % dffRoiMinusDffNpil uses sgolayfilt from the Signal Processing
            % Toolbox, which the module manifest lists as optional.
            testCase.assumeTrue(exist('sgolayfilt', 'file') == 2, ...
                'Signal Processing Toolbox is not available')

            signalArray = testCase.createRoiSignals(2);
            dff = testCase.computeDff(signalArray, 'dffFcn', 'dffRoiMinusDffNpil');

            testCase.verifySize(dff, [testCase.NumSamples, testCase.NumRois])
            testCase.verifyTrue(all(isfinite(dff), 'all'))
        end
    end
end
