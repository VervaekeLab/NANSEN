classdef CranialWindow < fovmanager.mapobject.BaseObject
    
    properties (Constant = true, Transient = true)
        defaultShapes = {'Trapezoidal 3x5mm', 'Round 2.5mm', 'Custom Trapezoid'}
    end
    
    properties
        brainSurfaceAlphaMap
        fovArray = fovmanager.mapobject.FoV.empty
    end
    
    properties (Transient)
        boundaryWidth = 2;
        boundaryColor = 'k';
    end
    
    methods
        
        function obj = CranialWindow(varargin)
        % Initialize Cranial Window
        %
        %   CranialWindow(fovmanager, centerPosition, size) creates a new
        %   cranial window position in the FoV manager.
        %
        %   CranialWindow(fovmanager, S) where S is a struct of cranial
        %   window properties will recreate an already existing window.
        %
        %   CranialWindow(S) creates a CranialWindow object, but does not
        %   do any plotting.
        
            if isa(varargin{1}, 'fovmanager.App')
                fmHandle = varargin{1};
                varargin = varargin(2:end);
            elseif isa(varargin{1}, 'matlab.graphics.axis.Axes')
                hAx = varargin{1};
                varargin = varargin(2:end);
            end
            
            if isa(varargin{1}, 'struct')
                obj.fromStruct(varargin{1})
            else
                % Assume 1st argument is a position vector
                validateattributes(varargin{1}, {'numeric'}, {'numel', 2})
                centerPosition = varargin{1};
                
                % Assume 2nd argument is a shape argument
                shape = validatestring(varargin{2}, obj.defaultShapes);
                
                obj.center = centerPosition;
                obj.shape = shape;
                
                % Set edge coordinates based on center and shape.
                obj.setWindowCoordinates
                
            end
            
            % Plot window boundary and show image if present.
            if exist('fmHandle', 'var')
                obj.displayObject(fmHandle)
                
            elseif exist('hAx', 'var')
                obj.guiHandle = hggroup(hAx);
                obj.plotBoundary()
            end
        end
        
        function propList = getNonTransientProperties(obj)
        %getNonTransientProperties Get properties that are not transient
        %
        %   This implementation is different from the superclass
        %   implementation in that it removes the fovArray property.
        %
        %   The fovArray should be saved, but it is treated as a special
        %   case in this subclass' toStruct implementation, because each
        %   fov needs to be converted to struct as well.
        
            propList = properties(obj);
            transientProperties = utility.class.findproperties(obj, 'Transient');
            propList = setdiff(propList, transientProperties);
            propList = setdiff(propList, 'fovArray');
        
        end
        
        function S = toStruct(obj)
            S = toStruct@fovmanager.mapobject.BaseObject(obj);
            
            for i = 1:numel(obj)
                S(i).fovArray = obj(i).fovArray.toStruct();
            end
        end
        
        function fromStruct(obj, S)
            fromStruct@fovmanager.mapobject.BaseObject(obj, S)
            
            % Fix some unexpected name changes....
            if isfield(S, 'brainSurfaceImage')
                obj.image = S.brainSurfaceImage;
            end
            
            % Fix some unexpected name changes....
            if isfield(S, 'brainSurfaceAlpha')
                obj.brainSurfaceAlphaMap = S.brainSurfaceAlpha;
            end
        end
        
        function displayName = getDisplayName(obj, keyword)
            
            if nargin < 2 || isempty(keyword)
                keyword = '';
            end
            
            switch keyword
                case 'image'
                    displayName = 'Brain Surface';
                case 'class'
                    displayName = utility.string.varname2label(class(obj));
                    displayName = strrep(displayName, 'fovmanager.mapobject.', '');
                otherwise
                    displayName = 'Window';
            end
        end
        
        function showImage(obj)
            obj.updateImage()
        end
        
% % % % Add or edit properties.

        function setWindowCoordinates(obj)
           
            % Set list of window edge coordinates nx2 array of (x, y)
            
            switch obj.shape
                case {'Trapezoidal 3x5mm', 'Custom Trapezoid'}
                    windowCoords =  [-1.5, -2.5, 2.5, 1.5; ...
                                     2.5, -2.5, -2.5, 2.5]';
%                     windowCoords(:, end+1) = windowCoords(:, 1);
                    
                case {'Round 2.5mm'}
                    theta = linspace(0, 2*pi, 100);
                    rho = ones(size(theta))*2.5/2;
                    [x, y] = pol2cart(theta, rho);
                    
                    windowCoords = [x', y'];
                                                        
            end
            
            obj.edge = windowCoords + obj.center;
            
        end
        
        function addImage(obj)
            
            disp('Find a picture of the brain surface')
            
            imOrig = fovmanager.fileio.openimg();
            if numel(size(imOrig))==2; imOrig = repmat(imOrig, 1,1,3); end
            if isempty(imOrig); return; end
            
            imSize = size(imOrig);
            if imSize(1) > 1000
                newSize = imSize(1:2) ./ imSize(1) .* 1000;
                imOrig = imresize(imOrig, newSize);
            end
            
            % Open image in imviewer
            hImviewer = imviewer(imOrig);
            hImviewer.ImageDragAndDropEnabled = false;
            
            % Get figure handle and set figure title
            hFigure = hImviewer.Figure;
            hFigure.Name = 'Mark Window Position on Brain Surface Image';
            
            % Get window coordinates in the image from user
            coords = obj.interactiveWindowPlacement(hImviewer);
            if isempty(coords); return; end
            
            % Rotate image if it was rotated while fitting the window.
            theta = hImviewer.imTheta;
            if theta ~= 0
                imOrig = imrotate(imOrig, theta, 'bicubic', 'crop');
            end
            
            % Quit imviewer. Not needed anymore
            hImviewer.quitImviewer; clear hImviewer
            
            if isempty(coords); return; end
            
            % Update window coordinates
            switch obj.shape
                
                case 'Round 2.5mm'
                    assert(coords(3)==coords(4), 'Window should be circular')
                    radius = coords(3)/2;
                    winCenter = coords(3:4)/2;
                    pixPerMm = repmat( 2*radius ./ 2.5, 1, 2);
                    
                    rcc = coords;
                    
                    % Calculate outline coordinates in pixel coords...
                    theta = linspace(0, 2*pi, 360);
                    rho = ones(size(theta))*radius;
                    [xBorder, yBorder] = pol2cart(theta', rho');
                    winCoordsPx = [xBorder, yBorder] + radius;
                    
                    [height, width] = deal(radius*2);
                    
                case {'Trapezoidal 3x5mm'}
                    
                    rcc = [min(coords), range(coords)];
                    
                    % Shift coordinates to upper right corner (1,1)
                    coords = coords - rcc(1:2) + [1,1];
                    
                    % Find center and height of window in pixels
                    height = rcc(4); width = rcc(3);
                    
% % %                     imCenter = [width/2+mean(coords([1,2], 1)), height/2+mean(coords([1,4], 2))];
                    winCenter = rcc(3:4)/2; % I think this fixes the offset problem further down
                    
                    % Calculate pixels per mm, assuming that window is 5mm
                    pixPerMm = [height ./ 5, width ./5 ];
                    winCoordsPx = coords;
               
                case 'Custom Trapezoid'
                    
                    rcc = [min(coords), range(coords)];

                    % Shift coordinates to upper right corner (1,1)
                    coords = coords - rcc(1:2) + [1,1];
                    
                    % Find center and height of window in pixels
                    height = rcc(4); width = rcc(3);
                    winCenter = rcc(3:4)/2;
                    
                    answer = inputdlg({'Enter height...', '...and/or width (in mm)'}, 'Size request');
                    if isempty(answer); return; end
                    answer = str2double(answer);

                    pixPerMm = [height./answer(1), width./answer(2)];
                    if any(isnan(pixPerMm))
                        pixPerMm(isnan(pixPerMm)) = pixPerMm(~isnan(pixPerMm));
                    end
                    winCoordsPx = coords;

            end
            
            % Crop image and get alphamap.
            imCropped = imcrop(imOrig, rcc);
            alphaData = poly2mask(winCoordsPx(:,1), winCoordsPx(:,2), rcc(4)+1, rcc(3)+1);
          
            if numel(size(imCropped)) == 2
                imCropped = repmat(imCropped, 1, 3);
            end
            
            % Add image and imhandle to fov database
            obj.image = flipud(imCropped);
            obj.brainSurfaceAlphaMap = flipud(alphaData);
            
            % Todo: Should put the following to the updateImage method
            
            % Get rect coordinates of cropped image and window offset
            rcc = [0, 0, rcc(3:4)] + 1;
            xoffset = obj.center(1);
            yoffset = obj.center(2);

            % Calculate image and outline coordinates in map units...
            xData = (rcc([1,3]) - winCenter(1)) ./ pixPerMm(2) + xoffset;
            yData = (rcc([2,4]) - winCenter(2)) ./ pixPerMm(1) + yoffset;
            
            xCoords = (winCoordsPx(:,1)-winCenter(1)) ./ pixPerMm(2) + xoffset;
            yCoords = (winCoordsPx(:,2)-winCenter(2)) ./ pixPerMm(1).*-1 + yoffset;
            
            % Show image in main plot
            hIm = findobj(obj.guiHandle, 'Tag', 'Brain Surface Image');
            hEdge = findobj(obj.guiHandle, 'Tag', 'Window Outline');
            
            if isempty(hIm)
                hIm = image(obj.image, 'XData', xData, 'YData', yData, 'Parent', obj.guiHandle);
                hIm.AlphaData = flipud(alphaData)*0.6;
                hIm.Tag = 'Brain Surface Image';
                hIm.HitTest = 'off';
                hIm.PickableParts = 'none';
                uistack(hIm, 'bottom')
                
                mTmp = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Show Brain Surface Image');
                mTmp2 = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Set Image Transparency');
                if ~isempty(mTmp)
                    mTmp.Enable = 'on';
                    mTmp2.Enable = 'on';
                    mTmp.Text = 'Hide Brain Surface Image';
                end
                
            else
                hIm.CData = obj.image;
                
                hIm.XData = xData;
                hIm.YData = yData;
                
                hIm.AlphaData = obj.brainSurfaceAlphaMap*0.6;
            end

%             % Close the circle...
%             xCoords(end+1) = xCoords(1);
%             yCoords(end+1) = yCoords(1);
            
% % %             % Somehow, the image and window outline coordinates are not
% % %             % perfectly aligned. Gave up on figuring out why, and fix it
% % %             % temporarily like this:
% % %             corrFactorX = mean(xData - [min(xCoords), max(xCoords)]);
% % %             corrFactorY = mean(yData - [min(yCoords), max(yCoords)]);
% % %             xCoords = xCoords + corrFactorX;
% % %             yCoords = yCoords + corrFactorY;

            % Update window outline according to new coordinates.
            obj.edge = [xCoords, yCoords];
            set( hEdge, 'XData', xCoords, 'YData', yCoords )
            
            mh = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Add Brain Surface Image...');
            if ~isempty(mh)
                mh.Text = 'Replace Brain Surface Image...';
            end
        end
        
        function coords = interactiveWindowPlacement(obj, hImviewer)
        %interactiveWindowPlacement UI to indicate window position in image.
        
            coords = [];
            
            axH = hImviewer.Axes;
            xLim = axH.XLim;
            yLim = axH.YLim;
            xRange = range(xLim); yRange = range(yLim);
            imSize = [yRange, xRange];

            % Set coordinates for roi initialization
            switch obj.shape
                case 'Round 2.5mm'
                    imroiFun = @imellipse;
                    posArg = [50, 50, min(imSize)-[100, 100]];
                    
                case {'Trapezoidal 3x5mm', 'Custom Trapezoid'}

                    imroiFun = @impoly;
                    windowCoords =  [-1.5, -2.5, 2.5, 1.5; ...
                                     -2.5, 2.5, 2.5, -2.5];
                    windowCoords = windowCoords ./ 5 .* min(imSize)*0.9;
                    windowCoords = windowCoords + fliplr(imSize/2)';

                    posArg = windowCoords';
                                        
            end
            
            % Create the imroi object
            hImroi = imroiFun(axH, posArg);
           
            % Make sure the selection constrained inside the image
            constrainInImageFcn = makeConstrainToRectFcn(func2str(imroiFun), [1,imSize(2)], [1, imSize(1)]);
            
            if contains(obj.shape, 'Round')
                % Make sure selection is circular
                setFixedAspectRatioMode(hImroi, true)
                hImroi.setPositionConstraintFcn(constrainInImageFcn);

            elseif contains(obj.shape, 'Trapezoidal 3x5mm')
                fcn = @(pos) obj.trapezoidalConstraintFcn(pos, hImroi, [3,5,5], imSize);
                hImroi.setPositionConstraintFcn(fcn)
                
            elseif contains(obj.shape, 'Custom')
                hImroi.setPositionConstraintFcn(constrainInImageFcn);

            end
            
            % Todo: add message saying press enter to finish..
            % imviewer.
            msg = 'Indicate window position. Press help button for how to rotate image. Press enter to finish';
            hImviewer.displayMessage(msg, [], 4)
            
            % Wait for user
            hFigure = hImviewer.Figure;
            hFigure.UserData.lastKey = '';
            
            while true
                uiwait(hFigure) % Will resume on keypress
                
                if ~ishghandle(hFigure)
                    break
                elseif strcmp(hFigure.UserData.lastKey, 'return')
                    coords = round(hImroi.getPosition);
                    break
                elseif strcmp(hFigure.UserData.lastKey, 'escape')
                    coords = [];
                    break
                end
            end
            
            % Retrieve coordinates
%             coords = round(hImroi.getPosition);
            delete(hImroi);
            
        end
        
        function constrainedPos = trapezoidalConstraintFcn(~, newPos, hTrapezoid, siz, imSize)
            
            % Make sure new positions are trapezoidal with given aspect
            % ratio.
            % siz = [a,b,h];
            %
            %
            %         a
            %      1-----4      |
            %     /       \     |
            %    /         \    | h
            %   /           \   |
            %  2-------------3  |
            %         b
            
            % Note: this function only works for trapezoids where b=h.
            % Small changes are needed for general cases. Also, it only
            % works for so-called isoscenes trapezoids.
            
            a=siz(1); b = siz(2); h = siz(3);
            
            % Find which corner has changed size
            origPos = hTrapezoid.getPosition();
            [ci, ~] = find( sum((origPos-newPos),2) ~= 0 ); %CornerIndex
            
            % Assign constrained pos
            constrainedPos = origPos;
            
            % If there was no change, return immediately
            if numel(ci) == 0; return; end
            
            % Find shifts in x and y
            deltaX = newPos(ci(1), 1) - origPos(ci(1), 1);
            deltaY = newPos(ci(1), 2) - origPos(ci(1), 2);
            
            % Find max allowed shifts
            bound = @(X) [min(X), max(X)];
            maxAllowedShiftsX = [1, imSize(2)] - bound(origPos(:,1));
            maxAllowedShiftsY = [1, imSize(1)] - bound(origPos(:,2));
            
            % Limit dx/dy according to imagesize
            if any(newPos(:, 1) < 1)
                deltaX = maxAllowedShiftsX(1);
            elseif any(newPos(:, 1) > imSize(2))
                deltaX = maxAllowedShiftsX(2);
            end
            
            if any(newPos(:, 2) < 1)
                deltaY = maxAllowedShiftsY(1);
            elseif any(newPos(:, 2) > imSize(1))
                deltaY = maxAllowedShiftsY(2);
            end
            
            % Calculate newposition of constrained Trapezoid
            if numel(ci) == 1 % One corner is moved

                % If corners are on the left side, change in width is
                % opposite of change in x. Same in Y if corners are on top
                if ci == 1 || ci == 2; sgnX = -1; else; sgnX = 1; end
                if ci == 1 || ci == 4; sgnY = -1; else; sgnY = 1; end
                
                % Assign change in size according to new position
                deltaW = sgnX * deltaX;
                deltaH = sgnY * deltaY;
               
                % If dW and dH pull in same direction, choose the largest
                if sign(deltaW) == sign(deltaH)
                    delta = max([deltaW, deltaH]);
                else % Choose the smallest absolute shift.                  % Choosing the largest in this case leads to instability
                    [~, ind] = min(abs([deltaW, deltaH]));
                    if ind == 1; delta = deltaW; else; delta = deltaH; end
                end

                % Lock the corner diagonally opposite to the moving corner
                lockedCorner = mod(ci+2, 4) + ((ci+2)==4)*4;                % Add 2 and reset if number exceeds 4.

                % Get bounding boxes of sides a (inner) and b (outer)
                [innerBBox, outerBBox] = deal(origPos);
                innerBBox([2,3], 1) = innerBBox([1,4],1);
                outerBBox([1,4], 1) = outerBBox([2,3],1);
                
                origH = range(innerBBox(:,2));
                origA = range(innerBBox(:,1));
                origB = range(outerBBox(:,1));
                
                % Find max allowed resize for each of the corners           % [minSize, maxSize]
                if ci == 1
                    maxAllowedResize = [-origB+10, min( [-maxAllowedShiftsX(1), -maxAllowedShiftsY(1)]) ];
                elseif ci == 2
                    maxAllowedResize = [-origB+10, min( [-maxAllowedShiftsX(1), maxAllowedShiftsY(2)]) ];
                elseif ci == 3
                    maxAllowedResize = [-origB+10, min( [maxAllowedShiftsX(2), maxAllowedShiftsY(2)]) ];
                elseif ci == 4
                    maxAllowedResize = [-origB+10, min( [maxAllowedShiftsX(2), -maxAllowedShiftsY(1)]) ];
                end
                
                % Limit resize
                if delta < maxAllowedResize(1)
                    delta = maxAllowedResize(1);
                elseif delta > maxAllowedResize(2)
                    delta = maxAllowedResize(2);
                end

                % Get the anchoring position (position of opposite corner)
                if lockedCorner == 1 || lockedCorner == 4
                    lockedPos = innerBBox(lockedCorner, :);
                else
                    lockedPos = outerBBox(lockedCorner, :);
                end
                   
                % Calculate new sizes.
                newH = origH + delta;
                newA = origA + delta/h*a;
                newB = origB + delta/h*b;
                
                % Calculate new bounding box. Different for each corner
                if lockedCorner == 1
                    newBBox = [ [0,0]; [0,newH]; [newA,newH]; [newA,0] ];
                elseif lockedCorner == 2
                    newBBox = [ [0,-newH]; [0,0]; [newB,0]; [newB,-newH] ];
                elseif lockedCorner == 3
                    newBBox = [ [-newB,-newH]; [-newB,0]; [0,0]; [0,-newH] ];
                elseif lockedCorner == 4
                    newBBox = [ [-newA,0]; [-newA,newH]; [0,newH]; [0,0] ];
                end
                
                newBBox = lockedPos + newBBox;
                constrainedPos = newBBox;
                
                % Calculate center position along x
                xCenter = newBBox(1,1) + abs(diff(newBBox([1,4], 1)))/2;
                
                % Set the x-position of either the upper or lower corners.
                if lockedCorner == 1 || lockedCorner == 4
                    constrainedPos(2,1) = xCenter - newB/2;
                    constrainedPos(3,1) = xCenter + newB/2;
                else
                    constrainedPos(1,1) = xCenter - newA/2;
                    constrainedPos(4,1) = xCenter + newA/2;
                end
                
            elseif numel(ci) > 1 % The whole trapezoid is moved
                constrainedPos = origPos + [deltaX, deltaY];
            end
                
            return

        end
        
% % % % Context menu on the gui object in fov manager
        
        function createContextMenu(obj, fmHandle)

            %Make sure to create the context menu in the right figure. No
            %input creates in the current figure
            hFig = fmHandle.hFigure;
            m = uicontextmenu(hFig);

            if ~isempty(obj.image)
                mitem = uimenu(m, 'Text', 'Replace Brain Surface Image...');
            else
                mitem = uimenu(m, 'Text', 'Add Brain Surface Image...');
            end
            
            mitem.Callback = @(src, event) obj.addImage();

            mitem = uimenu(m, 'Text', 'Show Brain Surface Image');
            mitem.Callback = @obj.toggleShowHideImage;
            mitem.Enable = 'off';
            
            mitem = uimenu(m, 'Text', 'Set Image Transparency');
            mitem.Callback = @fmHandle.showTransparencySlider;
            mitem.Enable = 'off';
            
            mitem = uimenu(m, 'Text', 'Hide Fovs In Window');
            mitem.Callback = @fmHandle.showFovsInWindow;

            if isempty(obj.fovArray)
                mitem.Enable = 'off';
            else
                mitem.Enable = 'on';
            end
            
            mitem = uimenu(m, 'Text', 'Add Injection', 'Separator', 'on');
            mitem.Callback = @(src, event) fmHandle.addInjections;
            
            mitem = uimenu(m, 'Text', 'Add FoV');
            mitem.Callback = @(src, event) fmHandle.addFov;

            mitem = uimenu(m, 'Text', 'Create FoV from session');
            mitem.Callback = @(src, event) fmHandle.createFovFromSession;
            
            if obj.isMovable
                mitem = uimenu(m, 'Text', 'Lock Position', 'Separator', 'on');
            else
                mitem = uimenu(m, 'Text', 'Unlock Position', 'Separator', 'on');
            end
            
            mitem.Callback = @obj.togglePositionLock;
            
            mitem = uimenu(m, 'Text', 'Delete Window');
            mitem.Callback = @obj.requestdelete;
            
            obj.guiHandle.UIContextMenu = m;
            
        end

        function setImageAlpha(obj, ~, alphaValue)
            
            if isempty(obj.image)
                
%                 hEdge = findobj(obj.guiHandle, 'Tag', 'Window Outline');
%                 hEdge.FaceAlpha = alphaValue;
%
            else
            
                hIm = findobj(obj.guiHandle, 'Tag', 'Brain Surface Image');

                alphaData = obj.brainSurfaceAlphaMap * alphaValue;
                if obj.orientation.theta ~= 0
                    alphaData = imrotate(alphaData, obj.orientation.theta, 'bicubic');
                end

                hIm.AlphaData = alphaData;
            end
        end
        
        function setWindowAlpha(obj, alphaValue)
            h = findobj(obj.guiHandle, 'type', 'patch');
            h.FaceAlpha = alphaValue;
        end
        
% % % % Functions for changing window position. Almost identical to FoV,
% but move method is different. Also, should other methods be active?
        
        function move(obj, shift, forceMove)
            if nargin < 3; forceMove = false; end
            
            if ~obj.isMovable && ~forceMove; return; end
            
            % Move window itself using the superclass move method
            move@fovmanager.mapobject.BaseObject(obj, shift, forceMove)
            
            % Move fovs
            for i = 1:numel(obj.fovArray)
                fovH = obj.fovArray(i);
%                 fovIsMovable = fovH.isMovable;
%                 fovH.isMovable = true;
                fovH.move(shift, true, false) % Add flag for to force move & to not update fov info
%                 fovH.isMovable = fovIsMovable;
            end
        end
        
        function rotate(obj, theta)
            
            if ~obj.isMovable; return; end

            obj.orientation.theta = obj.orientation.theta + theta;
                        
            % Rotate edges and image.
            obj.rotateBoundary()
            obj.updateImage()
            
            thetaShiftRad = deg2rad(-theta); % Change sign because the rotation angle is in image rotation coordinates, not in polar
            
            % Rotate each individual FOV in the window
            for i = 1:numel(obj.fovArray)
                fovH = obj.fovArray(i);
                fovIsMovable = fovH.isMovable;
                fovH.isMovable = true;
                
                % Revolve the fov around the windows center
                c1 = fovH.center - obj.center;
                [theta0, rho] = cart2pol(c1(1), c1(2));
                [x1, y1] = pol2cart(theta0 + thetaShiftRad, rho);
                c2 = [x1, y1];
                fovH.move(c2-c1)
                
                % Rotate the FOV itself.
                fovH.rotate(theta)
                fovH.isMovable = fovIsMovable;
            end
        end
        
        function fliplr(obj)
            
            if ~obj.isMovable; return; end
            
            if ~ismember(obj.orientation.theta, [0,180]) && ~isempty(obj.fovArray)
                errmsg = sprintf('Error: Horizontal flip not supported when \nwindow is rotated and contains FOVs');
                ME = MException('Window:hFLipNotImplemented', errmsg);
                throw(ME)
            end
            
            if mod(obj.orientation.theta, 180) == 90
                obj.orientation.isMirroredY = ~obj.orientation.isMirroredY;
            else
                obj.orientation.isMirroredX = ~obj.orientation.isMirroredX;
            end
            
            % Update displayed image
            obj.updateImage()

            % Move fovs. NB Won't work if fov image is rotated to an angle
            % different from steps of 90
            for i = 1:numel(obj.fovArray)
                fovH = obj.fovArray(i);
                fovIsMovable = fovH.isMovable;
                fovH.isMovable = true;
                
                % Calculate shift of FOV
                dx = obj.center(1) - fovH.center(1);
                fovH.move([dx*2, 0])
                
                % Flip fov image;
                if mod(fovH.orientation.theta, 180)==90
                    fovH.flipud();
                else
                    fovH.fliplr();
                end
                
                fovH.isMovable = fovIsMovable;
            end
        end
        
        function flipud(obj)
            
            if ~obj.isMovable; return; end

            if ~mod(obj.orientation.theta,180)==0 && ~isempty(obj.fovArray)
                errmsg = sprintf('Error: Vertical flip not supported when\nwindow is rotated and contains FOVs');
                ME = MException('Window:vFLipNotImplemented', errmsg);
                throw(ME)
            end
            
            if mod(obj.orientation.theta, 180) == 90
                obj.orientation.isMirroredX = ~obj.orientation.isMirroredX;
            else
                obj.orientation.isMirroredY = ~obj.orientation.isMirroredY;
            end
            
            % Update displayed image
            obj.updateImage()

            % Move fovs
            for i = 1:numel(obj.fovArray)
                fovH = obj.fovArray(i);
                fovIsMovable = fovH.isMovable;
                fovH.isMovable = true;
                
                % Calculate shift of FOV
                dy = obj.center(2) - fovH.center(2);
                fovH.move([0, dy*2])
                
                % Flip fov image;
                if mod(fovH.orientation.theta, 180)==90
                    fovH.fliplr();
                else
                    fovH.flipud();
                end
                
                fovH.isMovable = fovIsMovable;
            end
        end
    end
    
    methods (Access = protected)
        
        % % % % Plot Functions

        function updateImage(obj)
            
            hIm = findobj(obj.guiHandle, 'Tag', 'Brain Surface Image');
%             hEdge = findobj(obj.guiHandle, 'Tag', 'Window Outline');
            
            displayIm = obj.image;
            
            if obj.orientation.isMirroredX
                displayIm = fliplr(displayIm);
            end
            
            if obj.orientation.isMirroredY
                displayIm = flipud(displayIm);
            end
            
            imSize = size(displayIm);
            if isa(hIm, 'matlab.graphics.primitive.Image')
                alphaValue = median(hIm.AlphaData(:));
            else
                alphaValue = 0.5;
            end
            
            alphaData = obj.brainSurfaceAlphaMap * alphaValue;
            
            xCoords = obj.edge(:, 1); yCoords = obj.edge(:, 2);
            xLims = [min(xCoords), max(xCoords)];
            yLims = [min(yCoords), max(yCoords)];
            
            if obj.orientation.theta ~= 0
                
                xExtent = range(xCoords); yExtent = range(yCoords);
                
                % Make sure image is same aspect ratio as edge coords
                % before rotating it... Otherwise it does not work to set
                % the image x and y-limits as done below.
                imAr = (xExtent/yExtent) / (imSize(2)/imSize(1));
                if abs(imAr-1) > 0.01
                    displayIm = imresize(displayIm, [imSize(1), imSize(2)*imAr]);
                    alphaData = imresize(alphaData, [imSize(1), imSize(2)*imAr]);
                end
                
                % Specify corners coords, start upper left and go ccw
                imCornersX = [-0.5, -0.5, 0.5, 0.5] .* xExtent;
                imCornersY = [-0.5, 0.5, 0.5, -0.5] .* yExtent;
                                
                [theta, rho] = cart2pol(imCornersX, imCornersY);
                theta = theta + deg2rad(obj.orientation.theta);
                
                [imCornersX, imCornersY] = pol2cart(theta, rho);
                imCornersX = imCornersX + obj.center(1);
                imCornersY = imCornersY + obj.center(2);
                
                xLims = [min(imCornersX), max(imCornersX)];
                yLims = [min(imCornersY), max(imCornersY)];

                displayIm = imrotate(displayIm, obj.orientation.theta, 'bicubic');
                alphaData = imrotate(alphaData, obj.orientation.theta, 'bicubic');

            end
            
            if isempty(hIm)
                hIm = image(displayIm, 'XData', xLims, 'YData', yLims);
                hIm.AlphaData = alphaData;
                hIm.Parent = obj.guiHandle;
                hIm.Tag = 'Brain Surface Image';
                hIm.PickableParts = 'none';
                hIm.HitTest = 'off';
                uistack(hIm, 'down') % Edge should stay on top for visibility
                
                mTmp = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Show Brain Surface Image');
                mTmp2 = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Set Image Transparency');
                
                if ~isempty(mTmp)
                    mTmp.Enable = 'on';
                    mTmp.Text = 'Hide Brain Surface Image';
                end
                
                if ~isempty(mTmp2)
                    mTmp2.Enable = 'on';
                end
                
            else
                hIm.CData = displayIm;
                
                hIm.XData = xLims;
                hIm.YData = yLims;
                
                hIm.AlphaData = alphaData;
            end
        end
    end
    
    methods (Static)
        
        function windowShape = requestShape()
            
            % Todo: get available windows from static method or file.
            
            windowShape = '';
            
            availableWindows = fovmanager.mapobject.CranialWindow.defaultShapes;
                        
            [selectionInd, tf] = listdlg(...
                    'PromptString', 'Select Window Style:', ...
                    'SelectionMode', 'single', ...
                    'ListString', availableWindows, ...
                    'ListSize', [150, 75]);
            if ~tf; return; end
            
            windowShape = availableWindows{selectionInd};
        
        end
    end
end
