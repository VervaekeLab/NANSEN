
import nansen.twophoton.roi.compute.computeRoiImages

sData = ses.Data;
dff = sData.RoiSignals_Dff;

roiArray = ses.loadData('roiArray');
imStackMc = sData.TwoPhotonSeries_Corrected;
imStackMcDs = imStackMc.downsampleT(15);

dffStats = nansen.twophoton.roi.stats.dffprops(dff);

params.ImageType = {'Activity Weighted Mean', 'Diff Surround', 'Top 99th Percentile', 'Local Correlation'};

imArray = imStackMcDs.getFrameSet(1:imStackMcDs.NumTimepoints);
% downsample dff
dff_ds = resample(double(dff), imStackMcDs.NumTimepoints, size(dff,1));


imageData = computeRoiImages(imArray, roiArray, dff_ds', ...
        'ImageType', params.ImageType);
    
imageStats = nansen.twophoton.roi.stats.imageprops(imageData, roiArray);

stats = utility.struct.mergestruct(dffStats, imageStats);

names = fieldnames(imageData)';
nvPairs =  [names; cell(1,4)];
roiImages = struct(nvPairs{:});
for i = 1:numel(roiArray)
    for j = 1:numel(names)
        roiImages(i).(names{j}) = imageData.(names{j})(:, :, i);
    end
end


roiStats = table2struct(struct2table(stats));

filePath = ses.getDataFilePath('roiArray');
save(filePath, 'roiStats', '-append')
save(filePath, 'roiImages', '-append')