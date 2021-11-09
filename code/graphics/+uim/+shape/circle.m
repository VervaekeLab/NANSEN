function varargout = circle(radius, numCornerSegmentPoints)
%uim.shape.circle Create edgecoordinates for outline of a circle
% 
%   [edgeCoordinates] = uim.shape.circle(radius) creates 
%   edgeCoordinates for a circle with given radius.
%
%   [xCoords, yCoords] = uim.shape.rectangle(boxSize) returns xCoords and 
%   yCoords are separate vectors.

%   Written by Eivind Hennestad | Vervaeke Lab

    if nargin < 2; numCornerSegmentPoints = 25; end
    if nargin < 1; radius = 10; end
    
    varargout = cell(1, nargout);
    
    [varargout{:}] = uim.shape.rectangle([radius*2, radius*2], radius, numCornerSegmentPoints);

end
