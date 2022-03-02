classdef ThumbnailSelector < handle
    
    
    properties
        hTiledImageAxes
        Position
        Visible
        Figure
        Axes
        
        IsConstructed = false;
        
        toggleButtons
    end
    
    properties (Access = private)
        thumbNailGroups
        hScrollbar
        Position_
        
        currentGroup
        currentTiles
    end
    
    
    % todo: 
    % [] Add thumbnail/add tile
    % [] Add scrollbar
    % [] Keep thumbnails for different tabs
    % [] make number of tiles a property...
    
    
    methods 
        function obj = ThumbnailSelector(parent, imdata, labels, callbacks, varargin)
            
% % %             if ndims(imdata) == 3
                [imHeight, imWidth, nImages] = size(imdata);
% % %             elseif ndims(imdata) == 4
% % %                 [imHeight, imWidth, ~, nImages] = size(imdata);
% % %             end
% % %             obj.hTiledImageAxes = uim.graphics.tiledImageAxes(parent, ...
% % %                     varargin{:});     


            obj.hTiledImageAxes = uim.graphics.tiledImageAxes(parent, ...
                'gridSize', [3,1], 'imageSize', [256, 256], ...
                'normalizedPadding', 0.02, 'Visible', 'off');
            

            
            obj.hTiledImageAxes.highlightTileOnMouseOver = true;
            
            nImages = min([nImages, obj.hTiledImageAxes.nTiles]);
            
            
            if ndims(imdata) == 3
                obj.hTiledImageAxes.updateTileImage(imdata(:, :, 1:nImages), 1:nImages)
            elseif ndims(imdata) == 4
                obj.hTiledImageAxes.updateTileImage(imdata(:, :, :, 1:nImages), 1:nImages)
            end

            obj.hTiledImageAxes.updateTileText(labels(1:nImages), 1:nImages, 'FontSize', 12, 'Color','w')
            obj.currentTiles = 1:obj.hTiledImageAxes.nTiles;
            
            for i = 1:min( [obj.hTiledImageAxes.nTiles, nImages] )
                obj.hTiledImageAxes.tileCallbackFcn(callbacks{i}, i)
            end
            
            obj.Visible = 'off';
            
            obj.addThumbnailGroup('Projection', imdata, labels, callbacks);
            
            
            colormap( obj.hTiledImageAxes.Axes, gray(256) )
            
            obj.Figure = obj.hTiledImageAxes.Figure;
            obj.Axes = obj.hTiledImageAxes.Axes;
            obj.hTiledImageAxes.fitAxes;
            
            % Set this property so that text outside the axes is clipped.
            obj.Axes.ClippingStyle = 'rectangle';
            obj.IsConstructed = true;
            
            obj.onVisibleChanged()

            
        end
        
        function onVisibleChanged(obj)
            if obj.IsConstructed
                set(obj.Axes.Children, 'Visible', obj.Visible)
                obj.hScrollbar.Visible = obj.Visible;
            end
        end
        
        function set.Visible(obj, newState)
            obj.Visible = newState;
            obj.onVisibleChanged()
        end
        
        function changeColorMap(obj, newCmap)
            colormap( obj.hTiledImageAxes.Axes, newCmap )
        end

        function addThumbnailGroup(obj, name, imdata, labels, callbacks)
                        
            obj.thumbNailGroups.(name) = struct();
            obj.thumbNailGroups.(name).Images = imdata;
            obj.thumbNailGroups.(name).Labels = labels;
            obj.thumbNailGroups.(name).Callbacks = callbacks;
            
        end
        
        function addThumbnailToGroup(obj, groupName, imdata, label, callback)
            
            if contains( label, obj.thumbNailGroups.(groupName).Labels)
                return
            end
            
            obj.thumbNailGroups.(groupName).Images(:, :, end+1) = imdata;
            obj.thumbNailGroups.(groupName).Labels{end+1} = label;
            obj.thumbNailGroups.(groupName).Callbacks{end+1} = callback;
            
            obj.changeThumbnailClass(groupName)
            
        end
        
        function changeThumbnailClass(obj, thumbnailClass)

            % Todo: Update scrollbar and gridsize based on number of
            % images...
            
            
            obj.updateTabButtonStates(obj.toggleButtons, thumbnailClass)

            switch thumbnailClass
                case 'Projection'

                case 'Binning'
                
                case 'Filter'

            end
            obj.currentGroup = thumbnailClass;
            obj.updateScrollbar()
            
            S = obj.thumbNailGroups.(thumbnailClass);
            
            %nImages = numel(S.Labels);
            %obj.hTiledImageAxes.gridSize = [3, 1];
            
            IND = 1:3;
            obj.currentTiles = IND;
            
            obj.hTiledImageAxes.updateTileImage(S.Images(:, :, IND), IND)
            obj.hTiledImageAxes.updateTileText(S.Labels(IND), IND, 'FontSize', 12, 'Color','w')
            
            for i = IND
                obj.hTiledImageAxes.tileCallbackFcn(S.Callbacks{i}, i)
            end
            
        end
        
        function createScrollBar(obj)
        % Create a scrollbar on the panel if all the fields do not fit in the panel
    
            scrollbarPosition = [sum(obj.hTiledImageAxes.Axes.Position([1,3])), ...
                                 obj.hTiledImageAxes.Axes.Position(2), ...
                                 20, obj.hTiledImageAxes.Axes.Position(4)];
             
            
            opts = {'Orientation', 'Vertical', ...
                    'Maximum', 100, ...
                    'VisibleAmount', 100, ...
                    'Units', 'pixel', ...
                    'Position', scrollbarPosition, ...
                    'Visible', 'off'};

            obj.hScrollbar = uim.widget.scrollerBar(obj.Figure, opts{:});
            obj.hScrollbar.Callback = @obj.scrollValueChange;
            obj.hScrollbar.StopMoveCallback = @obj.stopScrollbarMove;
            
            %obj.hScrollbar.Visible = 'off';

        end
        
        function updateScrollbar(obj)

            % Todo: checkout timerseriesPlot for positioning of bar calculating
            % new value
            
            nTiles = obj.hTiledImageAxes.nTiles;
            
            S = obj.thumbNailGroups.(obj.currentGroup);
            nImages = numel(S.Labels);
            
            barLength = nTiles ./ nImages * 100;
            obj.hScrollbar.VisibleAmount = barLength;
            
            barInit = (obj.currentTiles(1)-1) ./nImages;
            obj.hScrollbar.Value = barInit * 100;
            
        end
        
        function scroll(obj, src, event)
            obj.hScrollbar.moveScrollbar(src, event)
        end
        
        function scrollValueChange(obj, scroller, ~)
            
            S = obj.thumbNailGroups.(obj.currentGroup);
            numImages = numel(S.Labels);
            
            i = round(scroller.Value./scroller.Maximum .* numImages) + 1;
            if i ~= obj.currentTiles(1)
                event = struct('incr', i - obj.currentTiles(1));
                obj.updateView([], event, 'incr')
            end
            
        end
        
        function stopScrollbarMove(obj, ~, deltaY)
            obj.updateView(struct('deltaY', deltaY), [], 'scrollbar');
        end
        
        function updateView(obj, src, event, mode)
            
            S = obj.thumbNailGroups.(obj.currentGroup);
            numImages = numel(S.Labels);
            
            switch lower(mode)
                
                case 'scrollbar'
                    deltaY = src.deltaY;

                    % DeltaY is a fractional change of the scrollbar position.
                    % It follows the the change of tiles is the fractional
                    % change of all the tiles...
                    n = round(numImages * deltaY);

                case 'scroll'
                
                    % Determine how many tiles to move across
                    if ismac % Mac touchpad is too sensitive...
                        i = ceil(event.VerticalScrollCount);
                    else
                        i = ceil(event.VerticalScrollCount);
                    end
                    n = round(obj.hTiledImageAxes.nCols * i);
                    
                    if n == 0; return; end
                    

                    
                case 'incr'
                    n = event.incr;

            end
            
            % Make sure to not exceed limits
            n = max( 1-obj.currentTiles(1), n );
            n = min( numImages-obj.currentTiles(end), n );

            obj.currentTiles = obj.currentTiles + n;

            IND = obj.currentTiles;
            
            obj.hTiledImageAxes.updateTileImage(S.Images(:, :, IND), 1:3)
            obj.hTiledImageAxes.updateTileText(S.Labels(IND), 1:3, 'FontSize', 12, 'Color','w')
            
            for i = 1:3
                obj.hTiledImageAxes.tileCallbackFcn(S.Callbacks{IND(i)}, i)
            end

            %updateScrollbar(obj)
            
        end
        
        function set.Position(obj, newValue)

            if ~isequal(obj.Position_, newValue)
                obj.Position_ = newValue;
                obj.onPositionChanged()
            end
        
        end
        
        function position = get.Position(obj)
            position = obj.Axes.Position;
        end
        
        function onPositionChanged(obj)
            
            if ~obj.IsConstructed
                return
            end

            obj.Axes.Position = obj.Position_;
            
            scrollbarPosition = [sum(obj.Axes.Position([1,3])), ...
                                 obj.Axes.Position(2), ...
                                 20, obj.Axes.Position(4)];
                             
            obj.hScrollbar.Position = scrollbarPosition;
            
        end
        
    end
    
    
    methods (Static)
        
        function updateTabButtonStates(hButtons, newState)
        %updateTabButtonStates Update states of a radiobutton-like group
            
        % todo: Move to toolbar. Or radiobuttongroup class...
        
            evtDataOn = uim.event.ToggleEvent(1);
            evtDataOff = uim.event.ToggleEvent(0);
            
            for i = 2:numel(hButtons)
                if strcmp(hButtons(i).Tag, newState)
                    hButtons(i).toggleState([], evtDataOn)
                else
                    hButtons(i).toggleState([], evtDataOff)
                end
            end
            
        end
        
    end
    
    
end
