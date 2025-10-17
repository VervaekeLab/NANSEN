classdef (Abstract) BaseObject < handle
    
    % Todo: Make a generalized constructor/ or make methods that will be
    % part of the subclass constructors.
    
    properties
        center
        shape
        edge
        
        image
        alpha % Currently not used, see fovmanager.mapobject.CranialWindow for example...
        
        orientation = struct('isMirroredX', 0, 'isMirroredY', 0, 'theta', 0) % todo, should this be part of properties?
        
    end
    
    % Properties that should not be saved when object is saved.
    properties (Transient = true)
        guiHandle
        isMovable = false
    end
    
    properties (Abstract, Transient, Dependent)
       boundaryWidth
       boundaryColor
    end
    
    methods (Abstract)
        createContextMenu(obj, fmHandle)
    end

    methods
        
% % % % Functions for deletion
        
        function requestdelete(obj, ~, ~)
           answer = questdlg('Are you sure? There is no way back...');
           switch answer
               case 'Yes'
                   delete(obj)
           end
        end
        
        function delete(obj)
            if ~isempty(obj.guiHandle) && isvalid(obj.guiHandle)
                delete(obj.guiHandle)
            end
        end
        
% % % %  Set/get methods...

        function set.image(obj, newImage)

            obj.image = newImage;
            
            % The image has to be a 3 channel image, so a BW image is
            % repeated across 3 channels.
            if numel(size(obj.image)) == 2
                obj.image = repmat(obj.image, 1,1,3);
            end
            % Todo: Figure out if this is necessary...
        end
        
% % % % Default methods for getting display information.

        function displayName = getDisplayName(obj, keyword)
        %getDisplayName Get a displayname to tag handles with...
            
            % Todo: Make this easier... Should not rely on displaynames in
            % different places. Totally random....
            
            if nargin < 2; keyword = ''; end
            
            switch keyword
                case {'class', ''}
                    displayName = utility.string.varname2label(class(obj));
                    displayName = strrep(displayName, 'fovmanager.mapobject.', '');
            end
        end
        
        function infoText = getInfoText(obj) %#ok<MANU>
            infoText = '';
        end
        
        function pos = getInfoPosition(obj)
            rad = nansen.util.range(obj.edge) / 2;
            pos(1) = obj.center(1);
            pos(2) = obj.center(2)+rad(2)+range(obj.guiHandle.Parent.Parent.YLim)*0.07;
        end
        
% % % % Functions for converting to/from struct

        function propList = getNonTransientProperties(obj)  % getPersistentProperties
        %getNonTransientProperties Get properties that are not transient

            propList = properties(obj);
            tranientProperties = utility.class.findproperties(obj, 'Transient');
            propList = setdiff(propList, tranientProperties);

        end
        
        function S = toStruct(obj)
            
            propertyList = obj.getNonTransientProperties();

            % Initialize an empty struct array
            S = struct(propertyList{1}, {});
            
            % Loop (supports object array)
            for i = 1:numel(obj)
                for j = 1:numel(propertyList)
                    S(i).(propertyList{j}) = obj(i).(propertyList{j});
                end
            end
        end
        
        function fromStruct(obj, S)

            fields = fieldnames(S);
            propertyList = getNonTransientProperties(obj);
            propertyList = intersect(propertyList, fields);
            
            for i = 1:numel(propertyList)
                obj.(propertyList{i}) = S.(propertyList{i});
            end
        end
        
% % % % Function for turning on/off the isMovable property

        function togglePositionLock(obj, src, ~)
            switch src.Text
                case 'Lock Position'
                    obj.isMovable = false;
                    src.Text = 'Unlock Position';
                case 'Unlock Position'
                    obj.isMovable = true;
                    src.Text = 'Lock Position';
            end
        end
        
% % % % Functions for moving or reshaping the object

        function move(obj, shift, forceMove)

            if nargin < 3; forceMove = false; end
            if ~obj.isMovable && ~forceMove; return; end
            
            for i = 1:numel(obj.guiHandle.Children)

                if isa(obj.guiHandle.Children(i), 'matlab.graphics.primitive.Group') && ...
                    strcmp(obj.guiHandle.Children(i).DisplayName, 'FoV') % do i need FoV test. shouldn't this be general?
                    continue
                
                elseif isa(obj.guiHandle.Children(i), 'matlab.graphics.primitive.Text')
                    obj.guiHandle.Children(i).Position(1) = ...
                        obj.guiHandle.Children(i).Position(1) + shift(1);
                    obj.guiHandle.Children(i).Position(2) = ...
                        obj.guiHandle.Children(i).Position(2) + shift(2);
                
                else
                    obj.guiHandle.Children(i).XData = ...
                        obj.guiHandle.Children(i).XData + shift(1);
                    obj.guiHandle.Children(i).YData = ...
                        obj.guiHandle.Children(i).YData + shift(2);
                end
            end
            
            obj.center = obj.center + shift;
            obj.edge = obj.edge + shift;

        end
        
        function rotate(obj, theta)
            
            if ~obj.isMovable; return; end

            obj.orientation.theta = obj.orientation.theta + theta;
            obj.orientation.theta = mod(obj.orientation.theta, 360);
            
            % Rotate edges and image.
            obj.rotateBoundary()
            obj.updateImage()
            
        end
        
        function fliplr(obj)
            
            if ~obj.isMovable; return; end

            obj.orientation.isMirroredX = ~obj.orientation.isMirroredX;
            
            % Update displayed image
            obj.updateImage()
            
        end
        
        function flipud(obj)
            
            if ~obj.isMovable; return; end

            obj.orientation.isMirroredY = ~obj.orientation.isMirroredY;
            
            % Update displayed image
            obj.updateImage()
            
        end
        
        function displayObject(obj, hParent, varargin)
            
            if isa(hParent, 'fovmanager.App')
                hAx = hParent.hAxes;
            end

            % Create guiHandle. This is a hggroup that's should contain all
            % handles that are part of this fovmanager.mapobject.BaseObject.
            obj.guiHandle = hggroup(hAx);
            
            % Set a displayname for the guiHandle
            displayName = obj.getDisplayName('class');
            
            obj.guiHandle.DisplayName = displayName; % e.g 'Cranial Window';
            
            obj.plotBoundary() % This method can be overwritten in subclass
            obj.plotCenterPoint()
            obj.plotInfo()

            obj.createContextMenu(hParent) % This method can be overwritten in subclass

            if ~isempty(obj.image)
                obj.updateImage() % This method can be overwritten in subclass
            end
        end
        
        function toggleShowHideImage(obj, src, ~)
            
            imageTag = [obj.getDisplayName('image'), ' ', 'Image'];
            hIm = findobj(obj.guiHandle, 'Tag', imageTag);
            
            switch src.Text
                case sprintf('Show %s', imageTag)
                    hIm.Visible = 'on';
                    src.Text = sprintf('Hide %s', imageTag);
                case sprintf('Hide %s', imageTag)
                    hIm.Visible = 'off';
                    src.Text = sprintf('Show %s', imageTag);
            end
        end
        
        function showInfo(obj)
            hTxt = findobj(obj.guiHandle, 'Tag', 'Info Text');
            infoText = obj.getInfoText();
            if ~isempty(infoText)
                hTxt.String = infoText;
                radius = nansen.util.range(obj.edge) / 2;
                
                hAx = ancestor(obj.guiHandle, 'Axes');
                hTxt.Position(2) = obj.center(2)+radius(2)+range(hAx.YLim)*0.07;
                hTxt.Visible = 'on';
            end
        end
        
        function updateInfo(obj)
            hTxt = findobj(obj.guiHandle, 'Tag', 'Info Text');
            infoText = obj.getInfoText();
            if ~isempty(infoText)
                hTxt.String = infoText;
            end
        end

        function hideInfo(obj)
            hTxt = findobj(obj.guiHandle, 'Tag', 'Info Text');
            hTxt.Visible = 'off';
        end
        
        function addImage(obj)
            
            loadedImage = fovmanager.fileio.openimg();
            if isempty(loadedImage); return; end
            
            obj.image = loadedImage;
            
            if numel(obj.guiHandle.Children) > 0 % If initialized...?
                obj.updateImage()
            end
            
            if isa(obj, 'FoV') % Stupid coding ftw.
                textLabel = 'Fov Image';
            else
                textLabel = 'Image';
            end
            
            mh = findobj(obj.guiHandle.UIContextMenu, 'Text', sprintf('Add %s...', textLabel));
            
            if ~isempty(mh)
                mh.Text = sprintf('Replace %s...', textLabel);
            end
            
            mh = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Set Image Transparency');
            mh.Enable = 'on';
            
        end
        
% % % % Functions for changing FOV position

        function resize(obj, newPos)
        % Will resize/reposition fov according to rectangle coordinates
        % newPos.
            
            % Todo: Should this be a superclass method?
            
            % Save state of isMovable
            isMovableState = obj.isMovable;
            obj.isMovable = true;
            
            % Calculate new position and shift of FoV
            oldCenter = obj.center;
            objectSize = newPos(3:4);
            newCenter = newPos(1:2) + objectSize/2;
            shift = newCenter-oldCenter;
            
            obj.move(shift)
            
            % Take care of images that are rotated. Depending on the angle,
            % x and y units will flip...
            if mod( obj.orientation.theta, 180 ) > 45
                objectSize = fliplr( newPos(3:4) );
            else
                objectSize = newPos(3:4);
            end
                        
            % Update edge coordinates.
            obj.edge = [ [-1;-1;1;1] * objectSize(1)/2,  ...
                         [1;-1;-1;1] * objectSize(2)/2 ] + obj.center;
            
% %             h = findobj(obj.guiHandle, 'Tag', 'Fov Outline');
% %             xCoords = obj.edge(:, 1); yCoords = obj.edge(:, 2);
% %             set(h, 'XData', xCoords, 'YData', yCoords)
                     
            obj.rotateBoundary() % Todo: This should be called updateBoundary...
            obj.updateImage()
            
% %             hImage = findobj(obj.guiHandle, 'Type', 'Image');
% %             hImage.AlphaData = imresize(hImage.AlphaData, fovSize*1000);
            
            obj.isMovable = isMovableState;

        end
        
        function setImageAlpha(obj, ~, alphaValue)
            
            if isempty(obj.image)
                
                hEdge = findobj(obj.guiHandle, '-regexp', 'Tag', 'Outline');
                hEdge.FaceAlpha = alphaValue;
                
            else
            
                if alphaValue == 0
                    alphaValue = 0.01;
                end
                
                hIm = findobj(obj.guiHandle, '-regexp', 'Tag', 'Image');

                alphaData = hIm.AlphaData;
                alphaData(alphaData ~= 0) = alphaValue;
                
                hIm.AlphaData = alphaData;
            end
        end
    end
    
    methods (Access = protected)
        
        function [xCoords, yCoords] = getBoundaryCoords(obj)
            xCoords = obj.edge(:, 1); yCoords = obj.edge(:, 2);
        end
        
% % % % Plot Functions

        function plotBoundary(obj)
            
            [xCoords, yCoords] = obj.getBoundaryCoords();
                  
            % Plot boundary
            h = patch(obj.guiHandle, xCoords, yCoords, 'b');
            
            h.LineWidth = obj.boundaryWidth;
            %h.EdgeColor = fovmanager.PLOTCOLORS.EdgeColor; % Todo, implement alternative...
            h.EdgeColor = obj.boundaryColor;
            h.FaceAlpha = 0.05;
                        
            h.Tag = [obj.getDisplayName, ' ', 'Outline'];   % boundary/border/edge
            
            h.PickableParts = 'visible';
            h.HitTest = 'off';
            
            if obj.orientation.theta ~= 0
                obj.rotateBoundary()
            end
        end
        
        function hIm = updateImage(obj)
            
            if isa(obj, 'FoV') % Ugh, it hurts...
                imageName = 'Fov Image';
            else
                imageName = 'Image';
            end
            
            hIm = findobj(obj.guiHandle, 'Tag', imageName);
            
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

            alphaData = ones(imSize(1:2)) * alphaValue;
            
            xCoords = obj.edge(:, 1); yCoords = obj.edge(:, 2);
            
            if strcmp( obj.shape, 'circle' )
                % Define center coordinates and radius
                x = imSize(2)/2;
                y = imSize(1)/2;
                radius = min(imSize(1:2)/2);
                
                [xx, yy] = ndgrid((1:imSize(1)) - y, (1:imSize(2)) - x);
                mask = (xx.^2 + yy.^2) > radius^2;
                alphaData(mask) = 0;
            end
            
            xLims = [min(xCoords), max(xCoords)];
            yLims = [min(yCoords), max(yCoords)];
            
            if obj.orientation.theta ~= 0
                
                xExtent = nansen.util.range(xCoords); yExtent = nansen.util.range(yCoords);
                
                % Make sure image is same aspect ratio as edge coords
                % before rotating it... Otherwise it does not work to set
                % the image x and y-limits as done below.
                imAr = (xExtent/yExtent) / (imSize(2)/imSize(1));
                if imAr~=1 && ~isempty(displayIm)
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
                hIm = image(obj.guiHandle, displayIm, 'XData', xLims, 'YData', yLims); %#ok<CPROP>
                %hIm.Parent = obj.guiHandle;
                hIm.AlphaData = alphaData;
                hIm.Tag = imageName;
                hIm.PickableParts = 'none';
                hIm.HitTest = 'off';
                uistack(hIm, 'down') % Edge should stay on top for visibility
                
                mTmp = findobj(obj.guiHandle.UIContextMenu, 'Text', sprintf('Show %s', imageName));
                mTmp2 = findobj(obj.guiHandle.UIContextMenu, 'Text', 'Set Image Transparency');
                
                if ~isempty(mTmp)
                    mTmp.Enable = 'on';
                    mTmp2.Enable = 'on';
                    mTmp.Text = sprintf('Hide %s', imageName);
                end
                
            else
                hIm.CData = displayIm;
                
                hIm.XData = xLims;
                hIm.YData = yLims;
                
                hIm.AlphaData = alphaData;
                hIm.Visible = 'on';
            end
            
            % Replace context menu text
            mh = findobj(obj.guiHandle.UIContextMenu, 'Text', sprintf('Add %s...', imageName));
            if ~isempty(mh)
                mh.Text = sprintf('Replace %s...', imageName);
            end
            
            if ~nargout
                clear hIm
            end
        end
        
        function plotCenterPoint(obj)
            
            xh = plot(obj.guiHandle, obj.center(1), obj.center(2), '+');
            xh.Color = 'k';
            xh.Visible = 'off';
            xh.Tag = 'CenterPoint';
        
            uistack(xh, 'top')
        end
        
        function rotateBoundary(obj)
            
            boundaryTag = [obj.getDisplayName, ' ', 'Outline'];
            h = findobj(obj.guiHandle, 'Tag', boundaryTag);

            [xCoords, yCoords] = obj.getBoundaryCoords();
            
            xCoords = xCoords - obj.center(1);
            yCoords = yCoords - obj.center(2);

            [theta, rho] = cart2pol(xCoords, yCoords);
            theta = theta - deg2rad(obj.orientation.theta);
            [xCoords, yCoords] = pol2cart(theta, rho);

            xCoords = xCoords + obj.center(1);
            yCoords = yCoords + obj.center(2);
            
            h.XData = xCoords;
            h.YData = yCoords;
            
        end
        
        function plotInfo(obj)
            rad = nansen.util.range(obj.edge) / 2;
            
            hTxt = text(obj.guiHandle, obj.center(1), obj.center(2)+rad(2)+0.1, '');
            
            hTxt.BackgroundColor = 'w';
            hTxt.EdgeColor = ones(1,3)*0.2;
            hTxt.Visible = 'off';
            hTxt.Tag = 'Info Text';
            hTxt.HitTest = 'off';
            hTxt.PickableParts = 'none';
            
            % Todo: consider a way to get this always on top. I.e should
            % not be part of the fov object, but just an object in
            % fovmanager. Why did I even do it like this...?
        end
    end
end

% Potentially faster update when moving multiple objects, i.e window with fovs
% but should clean up code...

% % % % numChildren = numel(obj.guiHandle.Children);
% % % % classes = cell(numChildren,1);
% % % % for j = 1:numChildren
% % % %     classes{j} = class(obj.guiHandle.Children(j));
% % % % end
% % % % skip = strcmp(classes, 'matlab.graphics.primitive.Group');
% % % %
% % % % tmpH = obj.guiHandle.Children(~skip);
% % % % classes = classes(~skip);
% % % %
% % % %
% % % % isText = strcmp(classes, 'matlab.graphics.primitive.Text');
% % % % if sum(isText) == 1
% % % %     tmpH(isText).Position(1:2) = tmpH(isText).Position(1:2) + shift;
% % % % else
% % % %     oldPos = get(tmpH(isText), 'Position');
% % % %     newPos = cellfun(@(pos) pos + [shift, 0], oldPos, 'uni', 0);
% % % %     set(tmpH(isText), 'Position', newPos);
% % % % end
% % % %
% % % % if sum(~isText)==1
% % % %     tmpH(~isText).XData = tmpH(~isText).XData + shift(1);
% % % %     tmpH(~isText).YData = tmpH(~isText).YData + shift(2);
% % % % else
% % % %     oldXData = get(tmpH(~isText), 'XData');
% % % %     oldYData = get(tmpH(~isText), 'YData');
% % % %     newXData = cellfun(@(xdata) xdata + shift(1), oldXData, 'uni', 0);
% % % %     newYData = cellfun(@(ydata) ydata + shift(2), oldYData, 'uni', 0);
% % % %     set(tmpH(~isText), {'XData'}, newXData, {'YData'}, newYData);
% % % % end
