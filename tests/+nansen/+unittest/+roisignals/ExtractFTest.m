classdef ExtractFTest < matlab.unittest.TestCase
    %ExtractFTest Unit tests for nansen.twophoton.roisignals.extractF.
    %
    %   The extracted signals are compared with the mean pixel values of
    %   hand-made masks. Three square rois lie in a 48-by-64 image: roi 1
    %   and roi 2 overlap in three columns and roi 3 has no neighbors.
    %
    %   Two tests are regression tests. In
    %   testNeuropilSignalLeavesOutNeighboringRois the rois are brighter
    %   than the background, so the neuropil signal only equals the
    %   background if no neuropil mask holds a pixel of any roi. The
    %   testSecondOutput* tests check that the second output holds the
    %   options that were used and not the default options.
    %
    %   Run tests:
    %       runtests('nansen.unittest.roisignals.ExtractFTest')

    properties (Constant, Access = private)
        ImageSize = [48, 64]
        NumFrames = 25
        AbsTol = 1e-9 % Signals are requested as double
    end

    methods (TestMethodSetup)
        function seedRandomNumberGenerator(testCase)
            originalState = rng();
            testCase.addTeardown(@() rng(originalState))
            rng(1, "twister")
        end
    end

    methods (Test)

        function testRoiSignalIsMeanOfNonOverlappingPixels(testCase)
            [rois, roiMasks] = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);
            isInOneRoi = sum(roiMasks, 3) == 1;

            signalArray = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, signalDataType="double");

            expected = meanInMasks(imageData, roiMasks & isInOneRoi);
            testCase.verifySize(signalArray, [testCase.NumFrames, 2, 3])
            testCase.verifyEqual(squeeze(signalArray(:, 1, :)), expected, ...
                AbsTol=testCase.AbsTol)
        end

        function testRoiSignalUsesOverlappingPixelsOnRequest(testCase)
            [rois, roiMasks] = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);

            signalArray = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, excludeRoiOverlaps=false, signalDataType="double");

            expected = meanInMasks(imageData, roiMasks);
            testCase.verifyEqual(squeeze(signalArray(:, 1, :)), expected, ...
                AbsTol=testCase.AbsTol)
        end

        function testNeuropilSignalLeavesOutNeighboringRois(testCase)
            [rois, roiMasks] = createRois(testCase.ImageSize);
            backgroundValue = 1000;
            imageData = createTwoLevelStack(any(roiMasks, 3), ...
                testCase.NumFrames, backgroundValue, 6000);

            signalArray = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, signalDataType="double");

            expected = backgroundValue * ones(testCase.NumFrames, 3);
            testCase.verifyEqual(squeeze(signalArray(:, 2, :)), expected, ...
                AbsTol=testCase.AbsTol)
        end

        function testImageMaskLeavesPixelsOutOfNeuropilSignal(testCase)
            rois = createRois(testCase.ImageSize);
            imageMask = true(testCase.ImageSize);
            imageMask(:, 1:8) = false; % Columns to the left of roi 1
            backgroundValue = 1000;
            imageData = createTwoLevelStack(~imageMask, ...
                testCase.NumFrames, backgroundValue, 9000);

            signalArray = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, imageMask=imageMask, signalDataType="double");

            expected = backgroundValue * ones(testCase.NumFrames, 3);
            testCase.verifyEqual(squeeze(signalArray(:, 2, :)), expected, ...
                AbsTol=testCase.AbsTol)
        end

        function testBatchExtractEqualsSerialExtract(testCase)
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);

            serialSignals = nansen.twophoton.roisignals.extractF(imageData, rois, ...
                extractFcn=@nansen.twophoton.roisignals.extract.serialExtract, ...
                roiMaskFormat="struct", signalDataType="double");
            batchSignals = nansen.twophoton.roisignals.extractF(imageData, rois, ...
                extractFcn=@nansen.twophoton.roisignals.extract.batchExtract, ...
                roiMaskFormat="sparse", signalDataType="double");

            testCase.verifyEqual(batchSignals, serialSignals, AbsTol=testCase.AbsTol)
        end

        function testSubsetOfRoisEqualsColumnsOfFullExtraction(testCase)
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);

            allSignals = nansen.twophoton.roisignals.extractF(imageData, rois);
            selectedSignals = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, roiInd=[3, 1]);

            testCase.verifyEqual(selectedSignals, allSignals(:, :, [3, 1]))
        end

        function testSecondOutputHoldsOptionsGivenByName(testCase)
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);

            [~, params] = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, createNeuropilMask=false, roiInd=[3, 1]);

            testCase.verifyFalse(params.createNeuropilMask)
            testCase.verifyEqual(params.roiInd, [3, 1])
        end

        function testSecondOutputHoldsResolvedDefaults(testCase)
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);

            [~, params] = nansen.twophoton.roisignals.extractF(imageData, rois);

            testCase.verifyEqual(params.roiInd, 1:3)
            testCase.verifyEqual(params.imageMask, true(testCase.ImageSize))
            testCase.verifyEqual(params.extractFcn, ...
                @nansen.twophoton.roisignals.extract.serialExtract)
            testCase.verifyTrue(params.createNeuropilMask)
        end

        function testOptionsStructEqualsNameValueArguments(testCase)
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);
            optionsStruct = struct('createNeuropilMask', false, 'roiInd', 2);

            [signalsFromStruct, paramsFromStruct] = ...
                nansen.twophoton.roisignals.extractF(imageData, rois, optionsStruct);
            [signalsFromNames, paramsFromNames] = ...
                nansen.twophoton.roisignals.extractF(imageData, rois, ...
                createNeuropilMask=false, roiInd=2);

            testCase.verifySize(signalsFromStruct, [testCase.NumFrames, 1])
            testCase.verifyEqual(signalsFromStruct, signalsFromNames)
            testCase.verifyEqual(paramsFromStruct, paramsFromNames)
        end

        function testNameValueArgumentReplacesStructField(testCase)
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);
            optionsStruct = struct('createNeuropilMask', true);

            signalArray = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, optionsStruct, createNeuropilMask=false);

            testCase.verifySize(signalArray, [testCase.NumFrames, 1, 3])
        end

        function testDefaultParameterStructIsAccepted(testCase)
            % The struct holds fields such as roiInd_ that configure the
            % options editor and are not options of extractF.
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);
            optionsStruct = nansen.twophoton.roisignals.extract.getDefaultParameters();

            signalsFromStruct = nansen.twophoton.roisignals.extractF( ...
                imageData, rois, optionsStruct);
            signalsFromDefaults = nansen.twophoton.roisignals.extractF(imageData, rois);

            testCase.verifyEqual(signalsFromStruct, signalsFromDefaults)
        end

        function testInvalidValueInOptionsStructThrowsError(testCase)
            rois = createRois(testCase.ImageSize);
            imageData = createRandomStack(testCase.ImageSize, testCase.NumFrames);
            optionsStruct = struct('pixelComputationMethod', 'max');

            testCase.verifyError( ...
                @() nansen.twophoton.roisignals.extractF(imageData, rois, optionsStruct), ...
                "MATLAB:validators:mustBeMember")
        end
    end
end

function [rois, roiMasks] = createRois(imageSize)
%createRois Two overlapping rois and one roi without neighbors
    roiMasks = false([imageSize, 3]);
    roiMasks(10:18, 10:18, 1) = true;
    roiMasks(10:18, 16:24, 2) = true;
    roiMasks(30:38, 40:48, 3) = true;

    rois = [RoI('Mask', roiMasks(:, :, 1)), ...
            RoI('Mask', roiMasks(:, :, 2)), ...
            RoI('Mask', roiMasks(:, :, 3))];
end

function imageData = createRandomStack(imageSize, numFrames)
%createRandomStack Stack of uniformly distributed uint16 pixel values
    imageData = uint16(randi([100, 4000], [imageSize, numFrames]));
end

function imageData = createTwoLevelStack(isBright, numFrames, backgroundValue, brightValue)
%createTwoLevelStack Stack with one value in bright pixels and one elsewhere
    frame = backgroundValue * ones(size(isBright), 'single');
    frame(isBright) = brightValue;
    imageData = repmat(frame, 1, 1, numFrames);
end

function signals = meanInMasks(imageData, masks)
%meanInMasks Mean pixel value per frame (rows) and mask (columns)
    numFrames = size(imageData, 3);
    numMasks = size(masks, 3);
    pixelValues = reshape(double(imageData), [], numFrames);

    signals = zeros(numFrames, numMasks);
    for i = 1:numMasks
        mask = masks(:, :, i);
        signals(:, i) = mean(pixelValues(mask(:), :), 1)';
    end
end
