function [roiImages, roiStats] = getRoiAppData(imArray, roiArray)
%getRoiAppData Get roi app data, i.e roi images and roistats

    import nansen.twophoton.roi.compute.computeRoiImages

    % Compute dff
    signalOpts = struct('createNeuropilMask', true);
    signalArray = nansen.twophoton.roisignals.extractF(imArray, roiArray, signalOpts);
    dff = nansen.twophoton.roisignals.computeDff(signalArray);

    % Compute roi images
    imageTypes = {'Activity Weighted Mean', 'Diff Surround', 'Top 99th Percentile', 'Local Correlation'};
    roiImageStruct = computeRoiImages(imArray, roiArray, dff', 'ImageType', imageTypes);
    
    % Compute roi stats
    dffStats = nansen.twophoton.roi.stats.dffprops(dff);

    imageStats = nansen.twophoton.roi.stats.imageprops(roiImageStruct, roiArray);

    stats = utility.struct.mergestruct(dffStats, imageStats);

    % Rearrange so that images are a structarray with one element per roi
    names = fieldnames(roiImageStruct)';
    nvPairs =  [names; cell(1,numel(names))];
    roiImages = struct(nvPairs{:});
    for i = 1:numel(roiArray)
        for j = 1:numel(names)
            roiImages(i).(names{j}) = roiImageStruct.(names{j})(:, :, i);
        end
    end

    % Rearrange roi stats to a nroi x1 struct array
    roiStats = table2struct(struct2table(stats));

end

