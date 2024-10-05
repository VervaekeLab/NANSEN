function [roiImages, roiStats] = getRoiAppData(imArray, roiArray, varargin)
%getRoiAppData Get roi app data, i.e roi images and roistats
%
%   [roiImages, roiStats] = getRoiAppData(imArray, roiArray) returns struct
%   arrays of roiImages and roiStats given an imageArray and a roiArray.
%
%   Output:
%       roiImages : 1 x numRois struct array where each value is a
%           thumbnail image. Contains the following fields:
%               'Activity Weighted Mean'
%               'Diff Surround'
%               'Top 99th Percentile'
%               'Local Correlation'
%           see nansen.twophoton.roi.compute.computeRoiImages for details
%
%       roiStats  : 1 x numRois struct array where each value is a
%           measurement on the roi's image or the roi's signal
%           see nansen.twophoton.roi.stats.dffprops and
%           nansen.twophoton.roi.stats.imageprops for details

    def = struct();
    def.RoiImageSize = [21, 21];

    opt = utility.parsenvpairs(def, [], varargin);

    import nansen.twophoton.roi.compute.computeRoiImages
    
    global fprintf % Use global fprintf if available
    if isempty(fprintf); fprintf = str2func('fprintf'); end
    
    % Compute rois signals for given image array
    fprintf('Extracting signals for computation of roi images...\n')
    signalOpts = struct('createNeuropilMask', true);
    signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArray, signalOpts);
    fprintf('Finished signal extraction\n')
    
    % Compute rois images
    imageTypes = {'Activity Weighted Mean', 'Diff Surround', 'Top 99th Percentile', 'Local Correlation'};
    roiImageStruct = computeRoiImages(imArray, roiArray, signalArray, 'ImageType', imageTypes, 'BoxSize', opt.RoiImageSize); % imported function
    
    % Compute roi stats
    dff = nansen.twophoton.roisignals.computeDff(signalArray);
    dffStats = nansen.twophoton.roi.stats.dffprops(dff);
    imageStats = nansen.twophoton.roi.stats.imageprops(roiImageStruct, roiArray);
    stats = utility.struct.mergestruct(dffStats, imageStats);

    % Rearrange roi images to a (nRoi x 1) struct array
    names = fieldnames(roiImageStruct)';
    nvPairs =  [names; cell(1,numel(names))];
    roiImages = struct(nvPairs{:});
    for i = 1:numel(roiArray)
        for j = 1:numel(names)
            roiImages(i).(names{j}) = roiImageStruct.(names{j})(:, :, i);
        end
    end

    % Rearrange roi stats to a (nRoi x 1) struct array
    roiStats = table2struct(struct2table(stats));

end
