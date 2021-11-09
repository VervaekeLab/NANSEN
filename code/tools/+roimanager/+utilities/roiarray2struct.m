function roiStruct = roiarray2struct(roiArray)

fieldnames = {  'uid', 'shape', 'coordinates', 'imagesize', 'boundary', ...
                'area', 'center', 'connectedrois', 'group', 'celltype', ...
                'structure', 'layer', 'tags', 'enhancedImage'};
            
intermediateCellArray = cell(numel(roiArray), numel(fieldnames));
for i = 1:numel(fieldnames)
    intermediateCellArray(:, i) = {roiArray.(fieldnames{i})};
end

roiStruct = cell2struct(intermediateCellArray, fieldnames, 2);

if iscolumn(roiStruct)
    roiStruct = roiStruct';
end

end
