classdef EstimateNeuropilMasksTest < matlab.unittest.TestCase
    %EstimateNeuropilMasksTest Unit tests for estimateNeuropilMasks.
    %
    %   Tests nansen.processing.roi.estimateNeuropilMasks on three square
    %   roi masks in a 64-by-64 image. Roi 1 and roi 2 are 3 pixels apart,
    %   so that roi 2 lies where the neuropil mask of roi 1 grows. Roi 3
    %   has no neighbors.
    %
    %   testMasksLeaveOutRoiPixels with the allTrue parameter is a
    %   regression test: an image mask that includes all pixels used to
    %   switch off excludeRoiFromNeuropil, and extractF always passes such
    %   a mask.
    %
    %   Run tests:
    %       runtests('nansen.unittest.roisignals.EstimateNeuropilMasksTest')

    properties (Constant, Access = private)
        ImageSize = [64, 64]
    end

    properties (TestParameter)
        % Image masks that leave out no pixels
        fullImageMask = struct( ...
            'empty', {logical.empty}, ...
            'allTrue', {true(64, 64)})
    end

    methods (Test)

        function testMasksLeaveOutRoiPixels(testCase, fullImageMask)
            roiMasks = createRoiMasks(testCase.ImageSize);

            neuropilMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, imageMask=fullImageMask);

            isRoiPixel = any(roiMasks, 3);
            testCase.verifyFalse(any(neuropilMasks & isRoiPixel, "all"))
        end

        function testNeighborRoiIsKeptWhenRoisAreNotExcluded(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);

            neuropilMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, excludeRoiFromNeuropil=false);

            maskOfRoi1 = neuropilMasks(:, :, 1);
            testCase.verifyTrue(any(maskOfRoi1 & roiMasks(:, :, 2), "all"), ...
                "The neuropil mask of roi 1 should reach into roi 2.")
            testCase.verifyFalse(any(maskOfRoi1 & roiMasks(:, :, 1), "all"), ...
                "A neuropil mask should never hold pixels of its own roi.")
        end

        function testMasksLeaveOutPixelsOutsideImageMask(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);
            imageMask = true(testCase.ImageSize);
            imageMask(:, 1:19) = false; % The columns to the left of roi 1

            neuropilMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, imageMask=imageMask);

            testCase.verifyFalse(any(neuropilMasks & ~imageMask, "all"))
            testCase.verifyTrue(any(neuropilMasks(:, :, 1), "all"))
        end

        function testImageMaskAppliesWhenRoisAreNotExcluded(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);
            imageMask = true(testCase.ImageSize);
            imageMask(:, 1:19) = false;

            neuropilMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, imageMask=imageMask, excludeRoiFromNeuropil=false);

            testCase.verifyFalse(any(neuropilMasks & ~imageMask, "all"))
        end

        function testMaskAreaReachesExpansionFactor(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);
            expansionFactor = 2;

            neuropilMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, neuropilExpansionFactor=expansionFactor);

            roiArea = squeeze(sum(roiMasks, [1, 2]));
            neuropilArea = squeeze(sum(neuropilMasks, [1, 2]));
            testCase.verifyGreaterThanOrEqual(neuropilArea, expansionFactor * roiArea)
        end

        function testLargerExpansionFactorGivesLargerMasks(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);

            smallMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, neuropilExpansionFactor=2);
            largeMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, neuropilExpansionFactor=4);

            smallArea = squeeze(sum(smallMasks, [1, 2]));
            largeArea = squeeze(sum(largeMasks, [1, 2]));
            testCase.verifyGreaterThan(largeArea, smallArea)
        end

        function testSeparationKeepsMasksAwayFromRois(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);

            neuropilMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, cellNeuropilSeparation=2);

            % Two steps cover the eight neighbors of every roi pixel
            isNextToRoi = imdilate(any(roiMasks, 3), ones(3));
            testCase.verifyFalse(any(neuropilMasks & isNextToRoi, "all"))
        end

        function testRoiIndSelectsAndOrdersMasks(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);

            allMasks = nansen.processing.roi.estimateNeuropilMasks(roiMasks);
            selectedMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, roiInd=[3, 1]);

            testCase.verifyEqual(selectedMasks, allMasks(:, :, [3, 1]))
        end

        function testRoiIndAllEqualsDefault(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);

            defaultMasks = nansen.processing.roi.estimateNeuropilMasks(roiMasks);
            allMasks = nansen.processing.roi.estimateNeuropilMasks( ...
                roiMasks, roiInd="all");

            testCase.verifySize(allMasks, size(roiMasks))
            testCase.verifyEqual(allMasks, defaultMasks)
        end

        function testImageMaskOfWrongSizeThrowsError(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);

            testCase.verifyError( ...
                @() nansen.processing.roi.estimateNeuropilMasks(roiMasks, imageMask=true(10, 10)), ...
                "NANSEN:RoiSignals:ImageMaskSizeMismatch")
        end

        function testInvalidRoiIndThrowsError(testCase)
            roiMasks = createRoiMasks(testCase.ImageSize);

            testCase.verifyError( ...
                @() nansen.processing.roi.estimateNeuropilMasks(roiMasks, roiInd=0), ...
                "NANSEN:RoiSignals:InvalidRoiIndices")
        end
    end
end

function roiMasks = createRoiMasks(imageSize)
%createRoiMasks Two neighboring rois and one roi without neighbors
    roiMasks = false([imageSize, 3]);
    roiMasks(20:30, 20:30, 1) = true;
    roiMasks(20:30, 34:44, 2) = true;
    roiMasks(45:50, 8:13, 3) = true;
end
