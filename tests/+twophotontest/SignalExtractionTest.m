classdef SignalExtractionTest < matlab.unittest.TestCase
%SignalExtractionTest Pins ROI signal extraction on a synthetic stack
%
%   Characterization tests for nansen.twophoton.roisignals.extractF. A
%   small in-memory image stack carries a known value inside one ROI and
%   zeros elsewhere, so the extracted ROI mean must reproduce that value
%   exactly and the neuropil mean must be zero.
%
%   Run tests:
%       runtests('twophotontest.SignalExtractionTest')

    properties (Constant, Access = private)
        ImageSize = [32, 32]
        NumFrames = 20
        AbsTol = 1e-3
    end

    methods (Access = private)

        function [imageData, rois, roiValues] = createStack(testCase)
        %createStack Two square ROIs with distinct time courses, zero elsewhere
            height = testCase.ImageSize(1);
            width = testCase.ImageSize(2);
            numFrames = testCase.NumFrames;

            maskA = false(height, width);
            maskA(8:12, 8:12) = true;
            maskB = false(height, width);
            maskB(20:24, 20:24) = true;

            rois = [RoI('Mask', maskA), RoI('Mask', maskB)];

            frameIndex = (1:numFrames)';
            roiValues = [100 + frameIndex, 300 - 2*frameIndex];

            imageData = zeros(height, width, numFrames, 'single');
            for iFrame = 1:numFrames
                frame = zeros(height, width, 'single');
                frame(maskA) = roiValues(iFrame, 1);
                frame(maskB) = roiValues(iFrame, 2);
                imageData(:, :, iFrame) = frame;
            end
        end

        function signalArray = extract(~, imageData, rois, varargin)
            signalArray = nansen.twophoton.roisignals.extractF(imageData, rois, varargin{:});
        end
    end

    methods (Test)

        function testRoiMeanReproducesTheInjectedValue(testCase)
            [imageData, rois, roiValues] = testCase.createStack();
            signalArray = testCase.extract(imageData, rois);

            % numSamples x (roi + one neuropil slice) x numRois
            testCase.verifySize(signalArray, [testCase.NumFrames, 2, 2])
            testCase.verifyEqual(double(squeeze(signalArray(:, 1, :))), ...
                roiValues, 'AbsTol', testCase.AbsTol)
        end

        function testNeuropilExcludesTheRoi(testCase)
            [imageData, rois] = testCase.createStack();
            signalArray = testCase.extract(imageData, rois);

            neuropil = double(squeeze(signalArray(:, 2, :)));
            testCase.verifyEqual(neuropil, zeros(testCase.NumFrames, 2), ...
                'AbsTol', testCase.AbsTol)
        end

        function testNeuropilCanBeSkipped(testCase)
            [imageData, rois, roiValues] = testCase.createStack();
            signalArray = testCase.extract(imageData, rois, 'createNeuropilMask', false);

            testCase.verifySize(signalArray, [testCase.NumFrames, 1, 2])
            testCase.verifyEqual(double(squeeze(signalArray(:, 1, :))), ...
                roiValues, 'AbsTol', testCase.AbsTol)
        end

        function testSubsetOfRoisIsExtracted(testCase)
            [imageData, rois, roiValues] = testCase.createStack();
            signalArray = testCase.extract(imageData, rois, 'roiInd', 2);

            testCase.verifySize(signalArray, [testCase.NumFrames, 2, 1])
            testCase.verifyEqual(double(signalArray(:, 1, 1)), ...
                roiValues(:, 2), 'AbsTol', testCase.AbsTol)
        end

        function testOutputTypeFollowsSignalDataType(testCase)
            [imageData, rois] = testCase.createStack();
            signalArray = testCase.extract(imageData, rois, 'signalDataType', 'double');
            testCase.verifyClass(signalArray, 'double')
        end
    end
end
