function varargout = rectangle(boxSize, cornerRadius, numCornerSegmentPoints)
%uim.shape.rectangle Create edgecoordinates for outline of a rectangle
%
%   [edgeCoordinates] = uim.shape.rectangle(boxSize) creates
%   edgeCoordinates for a box of size boxSize ([width, height]). This function
%   creates edgeCoordinates for each unit length of width and height.
%   edgeCoordinates is a nx2 vector of x and y coordinates where
%   n = 2 x (height+1) + 2 x (width+1)
%
%   [xCoords, yCoords] = uim.shape.rectangle(boxSize) returns xCoords and
%   yCoords are separate vectors.
%
%   [xCoords, yCoords] = createBox(boxSize, cornerRadius) creates the
%   rectangle boundary coordinates with rounded corners.
%
%   [xCoords, yCoords] = createBox(boxSize, cornerRadius, numCornerPoints)
%   additionally specifies how many points to dra for round corners. Higher
%   value gives a finer resolution (Default = 25)
%
% Coordinates starts in the upper left corner and traverses the box ccw
%
%        <--
%  ul _ _ _ _ _          y ^
%    |         | ^         |
%  | |         | |         |
%  v |_ _ _ _ _|            -------> x
%        -->               0

%   Written by Eivind Hennestad | Vervaeke Lab

    if nargin < 3; numCornerSegmentPoints = 25; end
    if nargin < 2; cornerRadius = 0; end
    
    boxSize = round(boxSize);
    
    if cornerRadius == 0
        xx = [0, 0, boxSize(1), boxSize(1)];
        yy = [boxSize(2), 0, 0, boxSize(2)];
        
    else
        
        numPoints = numCornerSegmentPoints * 4;
        segmentInd = repmat(1:4, numCornerSegmentPoints, 1);

        thetaOffset = (360 / numPoints) / 2;

        theta = linspace(thetaOffset, 360-thetaOffset, numPoints);
        theta = theta + 90; % 1str segment should be upper left
        theta = deg2rad(theta);

        rho = ones(size(theta)) .* cornerRadius;

        [xx, yy] = pol2cart(theta, rho);

        % Shift so that circle is in the 1st quadrant of the coordinate system
        xx = xx-min(xx); yy = yy-min(yy);

        isRightSide = segmentInd==3 | segmentInd==4;
        xx(isRightSide) = xx(isRightSide) + boxSize(1) - cornerRadius*2;

        isTopSide = segmentInd==1 | segmentInd==4;
        yy(isTopSide) = yy(isTopSide) + boxSize(2) - cornerRadius*2;

        xx(end+1) = xx(1);
        yy(end+1) = yy(1);
            
    end
    
if nargout == 1
    varargout = {[xx', yy']};
elseif nargout == 2
    varargout = {xx, yy};
end
