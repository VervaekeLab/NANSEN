function [hLines, hText] = plotRoiArray(hParent, roiArray, showNumbers)
%plotRoiArray draw outlines of rois in given axes
%
% [hLines] = plotRoiArray(ax, roiArray)
%   showNumbers is a boolean, used to plot numbers next to the outlines.

% Eivind Hennestad | 29 May 2018 | Vervaeke Lab

if nargin < 3; showNumbers = false; end

if isa(hParent, 'imviewer.App'); hParent = hParent.Axes; end
hAxes = hParent;

% Preallocate some arrays
nRois = numel(roiArray);
roiBoundaryCellArray = cell(2, nRois);
centerPosArray = zeros(nRois, 3);

% Find boundaries for all rois
for roiNo = 1:numel(roiArray)

    for j = 1:length(roiArray(roiNo).boundary)

        centerPosArray(roiNo, :) = [roiArray(roiNo).center, 0];
        
        boundary = roiArray(roiNo).boundary{j};

        if j == 1
            roiBoundaryCellArray{1, roiNo} = boundary(:,2); 
            roiBoundaryCellArray{2, roiNo} = boundary(:,1);

        else
            roiBoundaryCellArray{1, roiNo} = vertcat(roiBoundaryCellArray{1, roiNo}, nan, boundary(:,2));
            roiBoundaryCellArray{2, roiNo} = vertcat(roiBoundaryCellArray{2, roiNo}, nan, boundary(:,1));
        end
    end

end

% Plot lines and add text objects for all rois
hLines = plot(hAxes, roiBoundaryCellArray{:}, 'Color', [0.8, 0.8, 0.8]);
set(hLines, 'HitTest', 'off', 'PickableParts', 'none')

if showNumbers
    numbers = arrayfun(@(i) num2str(i), 1:nRois, 'uni', 0);
    hText = text(hAxes, centerPosArray(:, 1), centerPosArray(:, 2), numbers', 'Color', [0.8, 0.8, 0.8]);
    set(hText, 'HitTest', 'off', 'PickableParts', 'none')
end

if nargout == 0
    clearvars hLines hText
elseif nargout == 1
    clearvars hText
elseif nargout == 2 && ~showNumbers
    hText = [];
end


end