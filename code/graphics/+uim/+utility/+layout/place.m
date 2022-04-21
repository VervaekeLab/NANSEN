function place(hFigure, location, offset)
%PLACE Place figure at specified screen location
%
%   place(hFigure, location) places the figure in the specified location
%   location can be: bottom, top, center, left, right, southeast, southwest
%   northeast, northwest.
%
%   place(hFigure, location, offset) places the figure at a location with
%   an offset. offset can be a scalar or a vector with x- and y-offset.


    if nargin < 3; offset = [0, 0]; end
    screenSize = uim.utility.getCurrentScreenSize(hFigure);
    
    if numel(offset) == 1
        offset = [offset, offset];
    end

    switch location

        case 'bottom'
            hFigure.Position(2) = screenSize(2) + offset(2);

        case 'top'
            hFigure.Position(2) = screenSize(4) - hFigure.Position(4) + offset(2);

        case 'center'
            uim.utility.centerFigureOnScreen(hFigure)

        case 'left'
            hFigure.Position(1) = screenSize(1) + offset(1);

        case 'right'
            hFigure.Position(1) = screenSize(3) - hFigure.Position(3) + offset(1);
           
        case 'southeast'
            uim.utility.layout.place(hFigure, 'bottom', offset(1))
            uim.utility.layout.place(hFigure, 'right', offset(2))
            
        case 'southwest'
            uim.utility.layout.place(hFigure, 'bottom', offset(1))
            uim.utility.layout.place(hFigure, 'left', offset(2))
            
        case 'northeast'
            uim.utility.layout.place(hFigure, 'top', offset(1))
            uim.utility.layout.place(hFigure, 'left', offset(2))
            
        case 'northwest'
            uim.utility.layout.place(hFigure, 'top', offset(1))
            uim.utility.layout.place(hFigure, 'left', offset(2))
            
    end

end