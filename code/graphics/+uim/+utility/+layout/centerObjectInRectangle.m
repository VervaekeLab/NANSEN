function centerObjectInRectangle(hContainer, position)
%CENTEROBJECTINRECTANGLE Center a graphics object in a rectangle
%
%   centerObjectInRectangle(hContainer, position) centers the object
%   hContainer within the rectangle specified by position. hContainer must
%   be a graphics object that has a Position property, and the position
%   input should be specified as [x, y, w, h] where x and y is the bottom
%   left position.

    centerPosition = position(1:2) + position(3:4) / 2;
    hContainer.Position(1:2) = centerPosition - hContainer.Position(3:4) / 2;

end


