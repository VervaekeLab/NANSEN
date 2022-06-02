function [roiArray, classification, stats, images]  = vhlab(S)
%VHLAB Summary of this function goes here
%   Detailed explanation goes here
    
    imSize = [512,512]; % Todo: get from somewhere.
    
    roiArray = RoI.empty;
    
    for i = 1:numel(S.cellstructs)
        boundary = [S.cellstructs(i).xi', S.cellstructs(i).yi'];
        roiArray(i) = RoI('Polygon', boundary, imSize);
    end
    
    [classification, stats, images] = deal([]);
    
end

