function roiGroup = ensureRoiGroupMatchImageStack(roiGroup, imageStack)
% ensureRoiGroupMatchImageStack - Ensure that the roiGroup is compatible with the imageStack.
%
% Syntax:  roiGroup = ensureRoiGroupMatchImageStack(roiGroup, imageStack)
%
% Inputs:
%    roiGroup - A 1D or 2D array of roiGroup objects.
%    imageStack - An ImageStack object.
%
% Outputs:
%    roiGroup - A 2D array of roiGroup objects, with dimensions matching the
%               number of channels and planes in imageStack. If roiGroup was
%               already a 2D array with compatible dimensions, it is returned
%               unmodified. Otherwise, an empty 2D roiGroup array is created and
%               the roiGroups from the input roiGroup are copied into it.
%
% See also: roimanager.roiGroup nansen.stack.ImageStack

    numC = imageStack.NumChannels;
    numZ = imageStack.NumPlanes;

    if size(roiGroup, 2) ~= numC || size(roiGroup, 1) ~= numZ
        
        roiGroupArray(numZ, numC) = roimanager.roiGroup();
    
        % Initialize with empty roi groups
        for i = 1:numZ
            for j = 1:numC
                roiGroupArray(i,j) = roimanager.roiGroup(...
                    struct('roiArray', RoI.empty, 'PlaneNumber', i, 'ChannelNumber', j));
            end
        end
    
        for i = 1:numel(roiGroup)
            iC = roiGroup(i).ChannelNumber;
            iZ = roiGroup(i).PlaneNumber;
            roiGroupArray(iZ, iC) = roiGroup(i);
        end
    
        roiGroup = roiGroupArray;
    end
end
