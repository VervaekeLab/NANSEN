function [iA, iB] = findOverlappingRois(roiArrayA, roiArrayB, overlapThresh)
%FINDOVERLAPPINGROIS return rois and roi indices of overlapping rois
%
%   [IA, IB] = findOverlappingRois(roiArrayA, roiArrayB) returns indices of
%   rois in roiArrayA which are overlapping with rois in roIArrayB
%
%   [IA, IB]  = findOverlappingRois(roiArrayA, roiArrayB, overlapThresh) finds
%   overlapping rois determined by overlapThresh (fraction of overlap from
%   0 to 1). Default value of overlapThresh is 0.75.

if nargin < 3
    overlapThresh = 0.75;
end

centerCoordsA = cat(1, roiArrayA.center);
centerCoordsB = cat(1, roiArrayB.center);

% Merge highly overlapping rois.
if ~isempty(roiArrayB)
    
    % First, find rois that have center coordinates close together,
    % detecting a list of potentially overlapping rois.
    [xPosI, xPosJ] = meshgrid(centerCoordsA(:,1), centerCoordsB(:,1));
    [yPosI, yPosJ] = meshgrid(centerCoordsA(:,2), centerCoordsB(:,2));

    distance = sqrt( (xPosI-xPosJ).^2 + (yPosI-yPosJ).^2 );
    
    if isequal(roiArrayA, roiArrayB)
        [j, i] = find(distance < 10 & distance ~= 0);
    else
        [j, i] = find(distance < 10 & distance ~= 0);
    end

    % Second, go through rois that rois that are close together and
    % calculate fraction of overlap.
    overlap = zeros(numel(j), 1);
    for n = 1:numel(j)
        overlap(n) = RoI.calculateOverlap(roiArrayA(i(n)), ...
                        roiArrayB(j(n)));
    end
    
    % Find indices of rois that are highly overlapping
    isOverlapping = find(overlap > overlapThresh)';
    iA = i(isOverlapping);
    iB = j(isOverlapping);
    
else

    iA = [];
    iB = [];
    
end
