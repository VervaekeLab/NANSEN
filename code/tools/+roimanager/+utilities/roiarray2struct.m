function roiStruct = roiarray2struct(roiArray)

fieldnames = {  'uid', 'shape', 'coordinates', 'pixelweights', ...
                'imagesize', 'boundary', 'area', 'center', ...
                'connectedrois', 'group', 'celltype', ...
                'structure', 'layer', 'tags', 'enhancedImage'};

if isempty(roiArray)
    roiStruct = struct.empty;
    return
end

if isa(roiArray, 'cell') % Recursive over cell array
    roiStruct = cellfun(@(c) roimanager.utilities.roiarray2struct(c), roiArray, 'UniformOutput', false);
    return
end

intermediateCellArray = cell(numel(roiArray), numel(fieldnames));
for i = 1:numel(fieldnames)
    intermediateCellArray(:, i) = {roiArray.(fieldnames{i})};
end

roiStruct = cell2struct(intermediateCellArray, fieldnames, 2);

if iscolumn(roiStruct)
    roiStruct = roiStruct';
end
end
