classdef MultiSessionFovSwitcher < applify.ModularApp & applify.mixin.UserSettings

    
    % Todo: 
    % [x] Horizontal scrollbar
    % [x] Mouse scroll callback for horizontal scroller...
    % [x] Selected tile should move when scroller moves...
    % [x] Initialize or load a multisession roi array
    % [x] Add tile selection callback for opening selected session in
    %     roimanager.
    % [ ] Add support for multichannel rois
    % [ ] Dock i roimanager

    % [x] save rois an multi rois when changing sessions
    % [ ] migrate rois to all sessions when closing
    

    properties (Constant)
        AppName = 'Multisession Fov Selector'
    end

    properties (SetAccess = private)
        SelectedSession = [];       % Index for selected session
    end

    properties
        NumVisibleImages = 4        % Number of session fovs to display
    end
    
    properties (Dependent)
        NumSessions                 % Number of sessions in total
    end

    properties (Access = private) % Data properties
        SessionObjects              % Array of session objects
        SessionObjectStruct         % Some additional data (static) in a struct array 
        MultiSessionRoiCollection   % Instance of a MultiSessionRoiCollection
        ThumbnailImageArray         % Fov images in a numerical array (for easy indexing when updating view)
        ThumbnailLabels             % Cell array of session ids
        NumImageChannels
    end

    properties (Access = private) % UI properties
        Axes
        TiledImageAxes
        UIScrollbar
        CurrentTiles                % Indices for current visible tiles
        RoimanagerApp
    end

    properties (Constant, Hidden)
        USE_DEFAULT_SETTINGS = false
        DEFAULT_SETTINGS = struct
    end

    properties (Constant, Hidden = true) % Move to appwindow superclass
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end


    methods 
        
        function obj = MultiSessionFovSwitcher(sessionObjects, sessionObjectStruct, roimanagerApp)
        %MultiSessionFovSwitcher Class constructor

            % Todo: accept parent container handle as input
            %[h, varargin] = applify.ModularApp.splitArgs(varargin{:});
            % obj@applify.ModularApp(h);

            % Assign inputs to properties
            obj.SessionObjects = sessionObjects;
            obj.SessionObjectStruct = sessionObjectStruct;
            obj.RoimanagerApp = roimanagerApp;

            obj.NumVisibleImages = min([obj.NumVisibleImages, numel(obj.SessionObjects)]);

            obj.assignThumbnailData()

            obj.createFovSelectorWidget()
            obj.updateVisibleTiles()

            obj.isConstructed = true; %obj.onThemeChanged()

            obj.TiledImageAxes.highlightTileOnMouseOver = true;


            obj.Axes = obj.TiledImageAxes.Axes;
            obj.Axes.Units = 'pixel';
            obj.TiledImageAxes.fitAxes;

            % Set this property so that text outside the axes is clipped.
            obj.Axes.ClippingStyle = 'rectangle';
            
            pixelPosition = getpixelposition( obj.TiledImageAxes );
            obj.TiledImageAxes.Position(2) = obj.TiledImageAxes.Position(2)+20;
            obj.Panel.Position(3:4) = pixelPosition(3:4)+[20, 40];
            
            if strcmp( obj.mode, 'standalone' )          
                obj.Figure.Position([3,4]) = pixelPosition(3:4)+[20, 40];
                obj.Figure.Resize = 'off';
            end

            if numel(sessionObjects) > obj.NumVisibleImages
                obj.createScrollBar()
            end

            obj.TiledImageAxes.TileCallbackFcn = @obj.onSessionSelected;

            obj.onVisibleChanged() % Make sure everything is visible


            %S = obj.SessionObjectStruct(1);
            %obj.RoimanagerApp = roimanager.RoimanagerDashboard(S.ImageStack);
            %obj.RoimanagerApp.addRois(S.RoiArray)

            obj.SelectedSession = 1;
            obj.TiledImageAxes.selectTile([], [], 1); 

            % Load multi session rois
            obj.loadMultisessionRois()

            % Todo: 
            % Check that all sessions are present in multisession
            
            obj.Figure.CloseRequestFcn = @obj.onQuit;
            addlistener(obj.RoimanagerApp, 'ObjectBeingDestroyed', @obj.onQuit);
        end
        
        function onVisibleChanged(obj)
            if obj.isConstructed
                set(obj.Axes.Children, 'Visible', true)
                %obj.hScrollbar.Visible = obj.Visible;
            end
        end

        function onQuit(obj, src, ~)
            % Important to save rois first.

            if strcmp( src.Name, 'Multisession Fov Selector' )
                obj.saveCurrentRoiArray(obj.SelectedSession)
                obj.saveMultiSessionRois()
                
                % Update and save all other roi arrays:
                for i = 1:obj.NumSessions
                    if i == obj.SelectedSession
                        continue
                    else
                        obj.updateRoiArrayForSession(i)
                        obj.saveRoiArray(i)
                    end
                end

                delete(obj.RoimanagerApp)
                delete(obj)
            else
                close(obj.Figure)
            end
        end
        
    end
    
    methods 
        function numSessions = get.NumSessions(obj)
            numSessions = numel(obj.SessionObjects);
        end
    end

    methods (Access = protected)
        function onSettingsChanged(obj)

        end

        function onSizeChanged(obj, src, evt)
        %onSizeChanged Callback for size changed event on panel
            % Update cached pixel position value;
            onSizeChanged@applify.ModularApp(obj)
            %obj.Panel.Position = [0,0,1,1];
        end
    end

    methods (Access = private)
              
        function assignThumbnailData(obj)

            dim = ndims(obj.SessionObjectStruct(1).FovImage) + 1;
            fovImageArray = cat(dim, obj.SessionObjectStruct.FovImage);

            obj.ThumbnailImageArray = fovImageArray;
            obj.ThumbnailLabels = {obj.SessionObjects.sessionID};

            % Count image color channels
            if dim == 3
                obj.NumImageChannels = 1;
            elseif dim == 4
                obj.NumImageChannels = size(fovImageArray, 3);
            end

        end

        function createFovSelectorWidget(obj)
        %createFovSelectorWidget Create a "image spinner" for selecting FOV
            tileConfiguration = struct('DefaultTileColor', ones(1,3)*0.7, ...
                               'SelectedTileColor', [240   171    15]./255, ...
                               'DefaultColorMap', 'viridis', ...
                               'TextColor', ones(1,3)*0.8, ...
                               'SelectedTileAlpha', 0.01);

            obj.TiledImageAxes = uim.graphics.tiledImageAxes(obj.Panel, ...
                'tileConfiguration', tileConfiguration, ...
                'gridSize', [1, obj.NumVisibleImages], ...
                'imageSize', [256, 256], ...
                'normalizedPadding', 0.05, 'Visible', 'on', ...
                'numChan', obj.NumImageChannels);
        end

        function createScrollBar(obj)
        % Create a scrollbar on the panel if all the fields do not fit in the panel
            
            numImagesAll = numel(obj.SessionObjects);
            visibleAmount = obj.NumVisibleImages / numImagesAll * 100;

            scrollbarPosX = obj.TiledImageAxes.Position(1);
            scrollbarWidth = obj.TiledImageAxes.Position(3);
            scrollbarPosY = 10;
            scrollbarHeight = 10;
            
            scrollbarPosition = [scrollbarPosX, scrollbarPosY, scrollbarWidth, scrollbarHeight];
            
            opts = {'Orientation', 'Horizontal', ...
                    'Maximum', 100, ...
                    'VisibleAmount', visibleAmount, ...
                    'Units', 'pixel', ...
                    'Position', scrollbarPosition, ...
                    'Visible', 'on'};

            obj.UIScrollbar = uim.widget.scrollerBar(obj.Panel, opts{:});
            obj.UIScrollbar.Callback = @obj.scrollValueChange;
            obj.UIScrollbar.StopMoveCallback = @obj.stopScrollbarMove;

            obj.UIScrollbar.EnableMouseScroll = 'on';
            obj.UIScrollbar.showTrack();
            %obj.hScrollbar.Visible = 'off';
        end

        function scroll(obj, src, event)
            obj.UIScrollbar.moveScrollbar(src, event)
        end
        
        function scrollValueChange(obj, scroller, ~)
            
            numImages = numel(obj.SessionObjects);
            %scroller.Value
            i = round(scroller.Value./scroller.Maximum .* numImages) + 1;
            if i ~= obj.CurrentTiles(1)
                event = struct('incr', i - obj.CurrentTiles(1));
                obj.updateView([], event, 'incr')
            end
        end
        
        function stopScrollbarMove(obj, ~, deltaY)
            obj.updateView(struct('deltaY', deltaY), [], 'scrollbar');
        end
        
        function updateVisibleTiles(obj)
            
            % Todo: Combine with update view??
            tileInd = 1:obj.NumVisibleImages;


            if ndims(obj.ThumbnailImageArray) == 3
                obj.TiledImageAxes.updateTileImage(obj.ThumbnailImageArray(:, :, tileInd), tileInd)
            elseif ndims(obj.ThumbnailImageArray) == 4
                obj.TiledImageAxes.updateTileImage(obj.ThumbnailImageArray(:, :, :, tileInd), tileInd)
            end

            obj.TiledImageAxes.updateTileText( obj.ThumbnailLabels(tileInd), ...
                tileInd, 'FontSize', 12, 'Color','w')
            
            obj.CurrentTiles = tileInd;
        end

        function updateView(obj, src, event, mode)
                        
            % Todo
            numImages = numel(obj.SessionObjects);
            
            switch lower(mode)
                
                case 'scrollbar'
                    deltaY = src.deltaY;

                    % DeltaY is a fractional change of the scrollbar position.
                    % It follows that the change of tiles is the fractional
                    % change of all the tiles...
                    n = round(numImages * deltaY);

                case 'scroll'
                
                    % Determine how many tiles to move across
                    if ismac % Mac touchpad is too sensitive...
                        i = ceil(event.VerticalScrollCount);
                    else
                        %i = ceil(event.VerticalScrollCount);
                    end
                    n = round(obj.TiledImageAxes.nCols * i);
                    
                    if n == 0; return; end
                    
                case 'incr'
                    n = event.incr;

            end
            
            % Make sure to not exceed limits
            n = max( 1-obj.CurrentTiles(1), n );
            n = min( numImages-obj.CurrentTiles(end), n );

            obj.CurrentTiles = obj.CurrentTiles + n;


            % combine with updateVisibleTiles
            IND = obj.CurrentTiles;
            
            subs = repmat({':'}, 1, ndims(obj.ThumbnailImageArray));
            subs{end} = IND;

            % Get data that should be updated in tiles
            tileImages = obj.ThumbnailImageArray(subs{:});
            tileLabels = obj.ThumbnailLabels(IND);

            obj.TiledImageAxes.updateTileImage(tileImages, 1:obj.NumVisibleImages)
            obj.TiledImageAxes.updateTileText(tileLabels, 1:obj.NumVisibleImages, 'FontSize', 12, 'Color','w')
            
            %updateScrollbar(obj)

            if any(ismember(obj.CurrentTiles, obj.SelectedSession))
                idx = find(obj.CurrentTiles == obj.SelectedSession);
                obj.TiledImageAxes.selectTile([], [], idx);
            else
                obj.TiledImageAxes.selectTile([], [], []);
            end
            
        end

        function onSessionSelected(obj, src, evt, i)
            
            oldSelectionIdx = obj.SelectedSession;
            newSelectionIdx = obj.CurrentTiles(i);

            if ~isequal(newSelectionIdx, oldSelectionIdx)
                obj.SelectedSession = newSelectionIdx;
                
                % Save roi array (also adds it to multi session roi collection)
                obj.saveCurrentRoiArray(oldSelectionIdx)

                newRoiArray = obj.updateRoiArrayForSession(newSelectionIdx);
                S = obj.SessionObjectStruct(newSelectionIdx);

                obj.RoimanagerApp.changeSession(S.ImageStack, newRoiArray)
                
                obj.saveMultiSessionRois()
            end

            %disp(obj.SelectedSession)
        end

        function newRoiArray = updateRoiArrayForSession(obj, sessionIdx)
        
            sessonId = obj.SessionObjectStruct(sessionIdx).sessionID;

            newRoiArray = obj.MultiSessionRoiCollection.getRoiArray(sessonId);
            
            % Update in session object struct
            oldRoiArray = obj.SessionObjectStruct(sessionIdx).RoiArray;
            if iscell(oldRoiArray) && numel(oldRoiArray) > 1
                oldRoiArray = obj.SessionObjectStruct(sessionIdx).RoiArray;
                channelNumber = obj.MultiSessionRoiCollection(1).ImageChannel;
                planeNumber = 1;

                oldRoiArray{planeNumber, channelNumber} = newRoiArray;
                newRoiArray = oldRoiArray;
            end

            obj.SessionObjectStruct(sessionIdx).RoiArray = newRoiArray;

            if ~nargout
                clear newRoiArray
            end
        end

        function saveRoiArray(obj, sessionIdx)
            roiArray = obj.SessionObjectStruct(sessionIdx).RoiArray;
            obj.SessionObjects(sessionIdx).saveData('RoiArrayLongitudinal', roiArray)
            fprintf('Saved rois for session %s\n', obj.SessionObjectStruct(sessionIdx).sessionID)
        end

        function loadMultisessionRois(obj)
            varName = 'MultisessionRoiCrossReference';
            filePath = obj.SessionObjects(1).loadData(varName);

            S = load(filePath);
            obj.MultiSessionRoiCollection = S.multiSessionRois;
        end

        function saveMultiSessionRois(obj)
            varName = 'MultisessionRoiCrossReference';
            filePath = obj.SessionObjects(1).loadData(varName);

            S = struct;
            S.multiSessionRois = obj.MultiSessionRoiCollection;
            S.multiSessionRoisStruct = S.multiSessionRois.toStruct();
            save(filePath, '-struct', 'S')
        end

        function saveCurrentRoiArray(obj, sessionIdx)
            sessionID = obj.SessionObjects(sessionIdx).sessionID;
            fprintf('Saving rois for session %s\n', sessionID)

            %if ~isvalid(obj.RoimanagerApp); return; end

            % Get roi array from roimanager (Todo: Multichannel rois)
            % roiArray = obj.RoimanagerApp.ActiveRoiGroup.roiArray;
            
            % Ad hoc update to allow for working with individual channel of
            % multichannel roi arrays.
            channelNumber = obj.MultiSessionRoiCollection(1).ImageChannel;
            planeNumber = 1;

            roiGroup = obj.RoimanagerApp.RoiGroup(planeNumber, channelNumber);
            roiArray = roiGroup.roiArray;

            numPlanes = size(roiGroup, 1);
            if numPlanes > 1
                error('This method does not support multiplane recordings at the moment.')
            end

            % Add to multi session rois
            pushMode = 'replace';
            obj.MultiSessionRoiCollection = ...
                obj.MultiSessionRoiCollection.updateEntry(sessionID, roiArray, pushMode);

            synchMode = 'Mirror';
            obj.MultiSessionRoiCollection = ...
                obj.MultiSessionRoiCollection.synchEntries(sessionID, synchMode);
            
            % Get updated rois (if adding them to multisession array modifies them)
            updatedRois = obj.MultiSessionRoiCollection.getRoiArray(sessionID);
            
            % Update in session object struct
            oldRoiArray = obj.SessionObjectStruct(sessionIdx).RoiArray;
            if iscell(oldRoiArray) && numel(oldRoiArray) > 1
                obj.SessionObjectStruct(sessionIdx).RoiArray{planeNumber, channelNumber} = updatedRois;
                updatedRois = obj.SessionObjectStruct(sessionIdx).RoiArray;
            else
                obj.SessionObjectStruct(sessionIdx).RoiArray = updatedRois; %todo;
            end

            obj.SessionObjects(sessionIdx).saveData('RoiArrayLongitudinal', updatedRois)
            fprintf('Saved rois for session %s\n', sessionID)
        end

    end

end