function roiData = prepareRoiData(roiArray, imageStack, numFrames)
%prepareRoiData Prepare roidata for roi classification app
%
%   roiData = prepareRoiData(roiArray, imageStack) returns a struct
%   (roiData) that can be sent to the roiclassifier.

    if nargin < 3 || isempty(numFrames)
        numFrames = 5000;
    end

    roiData = struct;
    roiData.roiArray = roiArray;

    fprintf('Loading imagedata for preparation of  rois...\n')
    numFrames = min( [numFrames, imageStack.NumTimepoints] );
    imageData = imageStack.getFrameSet(1:numFrames);
                
    fprintf('Preparing roidata for classification...\n')
    imageTypes = {'enhancedAverage', 'peakDff', 'correlation', 'enhancedCorrelation'};
    [roiData.roiImages, roiData.roiStats] = roimanager.gatherRoiData(imageData, ...
            roiArray, 'ImageTypes', imageTypes);
        
    roiData.roiClassification = zeros(1, numel(roiArray));
    fprintf('Finished...\n')
end