function roiArray = struct2roiarray(roiStruct)

if isa(roiStruct, 'RoI')
    roiArray = roiStruct;
    return
end

if isempty(roiStruct)
    roiArray = RoI.empty;
    return
end

if isa(roiStruct, 'cell') % Recursive over cell array
    roiArray = cellfun(@(c) roimanager.utilities.struct2roiarray(c), roiStruct, 'UniformOutput', false);
    return
end

nRois = numel(roiStruct);
roiArray(nRois, 1) = RoI;

fieldnames = {  'uid', 'shape', 'coordinates', 'pixelweights', ...
                'imagesize', 'boundary', 'area', 'center', ...
                'connectedrois', 'group', 'celltype', ...
                'structure', 'layer', 'tags', 'enhancedImage'};

for f = 1:numel(fieldnames)
    if isfield(roiStruct, fieldnames{f})
        [roiArray(:).(fieldnames{f})] = roiStruct.(fieldnames{f});
    end
end
    
for i = 1:nRois
    
    % 2019-08-20 - Changed coordinates of rois with shape "mask"
    % from being a sparse logical to being a list of pixel
    % coordinates.
    if isa(roiArray(i).coordinates, 'logical')
        mask = full(roiArray(i).coordinates);
        roiArray(i) = roiArray(i).reshape(roiArray(i).shape, mask);
    end

    % Fix mistake of setting boundary to empty if roi is outside of
    % the image.
    if isempty(roiArray(i).boundary)
        roiArray(i) = roiArray(i).reshape(roiArray(i).shape, roiArray(i).coordinates);
    end
end

for i = 1:nRois
    roiArray(i) = RoI.loadobj(roiArray(i));
end

if iscolumn(roiArray)
    roiArray = roiArray';
end
end
