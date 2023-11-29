function rearrangeRoiArrayChannels(filePath, newChannelOrder)
% rearrangeRoiArrayChannels - Rearrange channels of a multichannel roiarray
%
%   Syntax:
%       rearrangeRoiArrayChannels(filePath, newChannelOrder)

    S = load(filePath);

    variableName = fieldnames(S);

    assert(numel(variableName)==1, ...
        'Expected file to have excactly one variable')
    variableName = variableName{1};

    assert( contains(lower(variableName), 'roiarray'), ...
        'File does not appear to contain rois')
    data = S.(variableName);

    assert(iscell(data), ...
        'Roi array is not a multichannel roi array')
    assert(size(data, 2)==numel(newChannelOrder), ...
        'Roi array has %d channels but the number of elements in the newChannelOrder is %d', ...
        size(data, 2), numel(newChannelOrder))
   
    data(:, newChannelOrder) = data(:, :);
    
    S.(variableName) = data;
    save(filePath, '-struct', 'S')
end