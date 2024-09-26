function changeRoiArrayDimensions(filePath, numPlanes, numChannels, force)
% changeRoiGroupDimension - Change the length of dimensions of a roi group
%
%   Syntax:
%       changeRoiArrayDimensions(filePath, numPlanes, numChannels)
%
%       changeRoiArrayDimensions(filePath, numPlanes, numChannels, force)
%       sets to optional boolean flag force (default = false). If force is
%       true, roi array can be shrunk, otherwise not

% Note: Only implemented for roigriup in file:
% Todo: support inputting a roigroup

    if nargin < 4; force = false; end
    
    S = load(filePath);

    variableName = fieldnames(S);
    assert(numel(variableName)==1, 'Expected file to have exactly one variable')
    variableName = variableName{1};

    assert( contains(lower(variableName), 'roiarray'), ...
        'File does not appear to contain rois')

    data = S.(variableName);

    if ~iscell(data)
        data = repmat({data}, numPlanes, numChannels);
    else
        [currentNumPlanes, currentNumChannels] = size(data);

        if currentNumPlanes < numPlanes
            data{numPlanes, :} = [];
        elseif currentNumPlanes > numPlanes
            if force
                data = data(1:numPlanes, :);
            else
                error(sprintf(...
                    ['Roi array currently has more planes than the provided value and data will be lost. \n', ...
                     'Run this function again using the force flag to resize the roi array anyway.'] ))
            end
        end

        if currentNumChannels < numChannels
            data{:, numChannels} = [];
        elseif currentNumChannels > numChannels
            if force
                data = data(:, 1:numChannels);
            else
                error(sprintf(...
                    ['Roi array currently has more planes than the provided value and data will be lost. \n', ...
                     'Run this function again using the force flag to resize the roi array anyway.'] ))
            end
        end
    end
    
    S.(variableName) = data;
    save(filePath, '-struct', 'S')
end
