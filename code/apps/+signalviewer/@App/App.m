classdef App < applify.ModularApp & applify.AppWithPlugin & applify.mixin.HasDialogBox
%signalviewer.App is a plotter for timeseries data
%
%   The signalviewer app is useful for plotting long timeseries data 
%   because  panning and zooming along the x-axis is done using 
%   mousescrolling and keyboard shortcuts.
%
%   How to use:
%       1) Plot a vector: 
%               signalviewer.App(Y)
%
%       2) Plot a set of vectors: 
%               signalviewer.App({A, B, C})
%
%       3) Plot vectors and give them names (for Legend, or getHandle method):
%               signalviewer.App({A, B, C}, 'Name', {'Speed', 'Position', 'Dff'})
%
%       4) Get the handle of the signalviewer app
%           h = signalviewer.App(Y)
%
%   Extra:
%    *  Logical vectors is plotted using patch instead of plot. Logical
%       vectors can therefore be used to highlight certain time periods
%       where some state is on or off.
%
%    *  To zoom in/out:
%           Press x/shift+x             - Zoom in/out on x axis
%           Press y/shift+y             - Zoom in/out on y axis
%          
%           Press shift+scroll          - Zoom in/out on x axis
%           Press y+scroll              - Zoom in/out on y axis
%
%           Scroll                      - Move along x-axis when zoomed in
%           Shift+leftarrow/rightarrow  - Pan x axis in bigger steps.
%
%    * use h.getHandle('name') to get the handle to line or patch objects.
%
%       To be continued.



    % Todo: 
    %   [ ] Fix x limits when time vector is supplied. Right now it only
    %       works when time is the default integer vector...
    %
    %   [ ] Create method for setting sampling rate
    %
    %  *[ ] Outsource zooming and panning tools to pointermanager. 
    %
    %   [ ] Create an abstract timeseriesViewer which supports changing
    %       sampleNumber or sampleTime... That way, its easier to link an
    %       imviewer and a signalplot if data are sampled at different fps.
    %
    %   [ ] TimeSeries can be multidimensional. Need to have methods take 
    %       care of both multidimensional time series array and multiple time series arrays. 
    %
    %   [ ] Implement a image raster map plot type. Use some features from
    %       imviewer (to set color limits for example).
    %       [ ] Toggle between showing rastermap and lines? Or have a
    %           subclass for rastermap plots..?
    %       [ ] Constrain extreme ylimits in zoom and pan mode...
    %       [ ] Add sorting methods for cells/traces of rastermap...
    %       
    %
    %   [ ] Update pointermanager/pointertool xlims if numSamples change
    %
    %   [x] Create method for mounting in panel..
    %
    %   [ ] Create a secondary axes for plotting annotations. Then we dont
    %       need to think about stacking...
    %       Q: how is this done in imviewer??
    %   [ ] Axes for event vectors... Place on bottom... 
    %   [ ] Resolve how to link axes when limits change. Just use linkprop
    %       function? 
    %   
    %
    %   [ ] Can I configure some of the axes properties to improve
    %       performance?
    %
    %   [ ] downsample
    %   [ ] yscrollbar
    %   [ ] dynamic update of data when panning..
    %
    %   methods:
    %       change sample
    %       change timepoint      
    %   properties:
    %       currentSampleNo / currentFrameNo
    %       currentTime
    %       numSamples
    %       timeLimits
    

% - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - 

    properties (Constant, Hidden)
        ICONS = uim.style.iconSet(signalviewer.App.getIconPath)
        DEFAULT_THEME = nansen.theme.getThemeColors('dark-gray');
    end
    
    properties (Constant)
        AppName = 'Signal Viewer'
    end
    
    properties
        
        YLimExtreme = struct('left', [], 'right', [])
        %XLimExtreme = struct('top', [], 'bottom', [])
    end
    
    properties (Dependent)
        Axes
        ActiveYAxis

        XLabelName
        YLabelName
    end
    
    properties (Access = private)
        TimeAxis % Class for show time along x-axis
    end
    
    properties
       
        settings = struct('ScrollFactorPanX', 5, ...
                          'ScrollFactorZoomX', 1, ...
                          'ScrollFactorZoomY', 1, ...
                          'DataPointPerPixel', 4, ...
                          'MaxNumTraces', 100 )%, ... % Todo...
%                           'YLimLeft', [0, 1], ...
%                           'YLimRight', [0, 1] )
                      
        plotMethod = 'stack' % stacked | overlaid
        
        Margins = [30,35,30,30]
        LinkedApps = [];
        SynchedApps applify.ModularApp
        
    end
    
    properties (Access = protected)
        ax
        
        % Todo: 
        EventAxes
        PlotAxes
        InteractionAxes
        
        PointerManager
        
        %ContextMenu 
        hContextMenu
        
        hScrollPanelX
        hScrollPanelY
        hScrollbarX
        hScrollbarY
        
        signalLegend
        
        hLineArray struct
        
        hlineCurrentFrame
        hlineTsArray
        
        TimeseriesPyramid
        
        tsNames = {} % Should be dependent
        tsArray %= timeseries.empty
        
        %yLimExtreme
        %tLimExtreme
        
        
        
        SynchTimer timer    % Timer for checking framenumber of synched app
    end
    
    properties (Access = protected)
        IsActive = true     % Flag indicating if gui is active or not. 
    end
    
    properties (Access = private)
        AxesLinkObject
        scrollMode = 'normal'; % move to pointermanager.
        scrollHistory = zeros(5,1)
    end
    
    properties (SetObservable = true, Access = public)
        firstFrameNo = 1
        nSamples = 1
        currentFrameNo = 1
    end
    
    
% - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - 
    
    methods % Structors
        
        function obj = App(varargin)
            
            [h, varargin] = applify.ModularApp.splitArgs(varargin{:});
            obj@applify.ModularApp(h);
            
            obj.customizeFigure();
            obj.createAxes() %Todo: what if properties are set?
            obj.createInteractionAxes()
            
            obj.DialogBox = uim.AxesDialogBox(obj.Axes);
            
            try
                obj.createScrollbar()
            end
            
            [nvPairs, varargin] = utility.getnvpairs(varargin{:});
            
            obj.parseInputs(nvPairs{:});
            
            obj.currentFrameNo = 1;
            
            % todo: parse for time series array, or remove first varargin
            %return
            tsArray = varargin{1}; varargin(1)=[]; 
            if nargin < 1 || isempty(tsArray)
                return
            end
            
            % Todo: Improve generalization of this class!
            if isa(tsArray, 'nansen.roisignals.RoiSignalArray')
                return
            end
            
                        
            % Hold here!
            hold(obj.ax, 'on')
            
            
            obj.parseTimeSeriesArray(tsArray, varargin{:}, nvPairs{:});

            if isa(obj.tsArray, 'timeseries')
                obj.plotTimeSeries(obj.tsArray);
                % Todo: time axis...
            elseif isa(obj.tsArray, 'timetable')
                obj.plotTimeTable(obj.tsArray);
                obj.TimeAxis = signalviewer.TimeAxis(obj.tsArray.Time, obj.ax);
            else
                
            end
            
            obj.setNewXLims()
            %obj.ax.ButtonDownFcn = {@obj.interactiveFrameChangeRequest, 'mousepress' };

            obj.colorLines()
            
            setappdata(obj.Figure, 'ViewerObject', obj)
            
            obj.isConstructed = true;
            
            delete(obj.FigureInteractionListeners.WindowMouseMotion)
            obj.Figure.WindowButtonMotionFcn = @obj.onMouseMotion;
            
            
            % Initialize the pointer interface.
            pif = uim.interface.pointerManager(obj.Figure, obj.ax, {'zoomIn', 'zoomOut', 'pan'});
            %pif.pointers.pan.buttonMotionCallback = @obj.moveImage;
            obj.PointerManager = pif;        
            obj.PointerManager.pointers.pan.constrainY = false;
            pif.initializePointers(obj.InteractionAxes, @signalviewer.pointerTool.eventAnnotator)
            
            addlistener(pif.pointers.eventAnnotator, 'EventModified', ...
                @obj.onEventVectorChanged);
            
            if ~nargout
                clear obj
            end
            
        end
        
        function quitApp(obj, ~, ~)
            
            
            if isvalid(obj)
                delete(obj)
            end
        end
        
        function delete(obj)
            
            % Stop and delete synch timer if it is on
            if ~isempty(obj.SynchTimer)
                stop( obj.SynchTimer )
                delete( obj.SynchTimer )
            end

            % Delete figure / panel for this app
            switch obj.mode
                case 'standalone'
                    if isvalid(obj.Figure)
                        delete(obj.Figure)
                    end
                case 'docked'
                    if isvalid(obj.Panel)
                        delete(obj.Panel)
                    end 
            end

        end
        
    end
    
    methods %Public methods
        
        function yyaxis(obj, side)
            
            dualAxisOn = numel(obj.ax.YAxis)==2;
            
            yyaxis(obj.ax, side)
            
            if ~dualAxisOn
                for i = 1:numel(obj.ax.YAxis)
                    obj.ax.YAxis(i).Color = obj.Theme.AxesForegroundColor;
                end
            end
            
            obj.ActiveYAxis = side;
            
        end
        
        function h = plot(obj, timeseriesArray)
           
            % Check that array does not already exist
            % Todo...
            
            % Add timeseriesArray to list of timeseriesArrays
            timeseriesArray = obj.parseTimeSeriesArray(timeseriesArray);
            
            % Plot time series arrays
            h = obj.plotTimeSeries(timeseriesArray);
            
            
            
            if nargout==0
                clear h
            end
        end
        
        function showLegend(obj, ~, ~)
            
            signalsToDisplay = obj.tsNames;
            
            lines = gobjects(numel(signalsToDisplay),  1);
            names = signalsToDisplay;
            
            for i = 1:numel(signalsToDisplay)
                signalName = signalsToDisplay{i};
                lines(i) = obj.getHandle(signalName, 1);
            end
              
            obj.signalLegend = legend(lines, names, 'AutoUpdate', 'off');
            obj.signalLegend.Orientation = 'horizontal';
            obj.signalLegend.Location = 'northwest';
            obj.signalLegend.Position(2) = 0.85;
            obj.signalLegend.Color = obj.Panel.BackgroundColor;
            obj.signalLegend.TextColor = obj.ax.XAxis.Color;
            obj.signalLegend.Box = 'off';
            obj.signalLegend.FontSize = 10;
            obj.signalLegend.Units = 'pixel';
            obj.signalLegend.Position(2) = sum(obj.ax.Position([2,4]))+5;
            obj.signalLegend.Interpreter = 'none';
            
        end
        
        function show(obj)
            
            if strcmp(obj.mode, 'standalone')
                obj.Figure.Visible = 'on';
                obj.IsActive = true;
            else
                obj.Panel.Visible = 'on';
                obj.IsActive = true;
            end
            
            
        end
        
        function hide(obj)
            
            if isvalid(obj.Figure)
                if strcmp(obj.mode, 'standalone')
                    obj.Figure.Visible = 'off';
                    obj.IsActive = true;
                else
                    obj.Panel.Visible = 'off';
                    obj.IsActive = true;
                end
            end
            obj.IsActive = false;
            
        end
        
    end
    
    methods %Set/get methods
                
        function set.currentFrameNo(obj, newValue)
            
            incr = newValue - obj.currentFrameNo;
            obj.currentFrameNo = newValue;
            obj.onFrameChanged(incr)

        end
        
        function set.YLimExtreme(obj, newValue)
            
            assert(isstruct(newValue) & isfield(newValue, 'left'), ...
                'Must specify extreme Y-limits as left or right')
            
            obj.YLimExtreme = newValue;
        end

        function set.YLabelName(obj, newValue)
            
            obj.ax.YLabel.String = newValue;
            
            if ~isempty(newValue)
                switch obj.ActiveYAxis
                    case 'left'
                        obj.Margins(1) = 40;
                    case 'right'
                        obj.Margins(3) = 40;
                end
            else
                switch obj.ActiveYAxis
                    case 'left'
                        obj.Margins(1) = 30;
                    case 'right'
                        obj.Margins(3) = 30;
                end
            end
            
            obj.resizePanel()

        end
        
        function set.XLabelName(obj, newValue)
            
        end
        
        function set.ActiveYAxis(obj, newValue)
            %yyaxis(obj, newValue)
        end
        
        function activeYAxis = get.ActiveYAxis(obj)
            activeYAxis = obj.ax.YAxisLocation;
        end
        
        function ax = get.Axes(obj)
            ax = obj.getAxes();
        end
        
    end

    methods (Access = protected) % App initialization and updating 
            
        function parseInputs(obj, varargin)
            
            
        end
        
        function setTitle(obj, titleStr)
            obj.Figure.Name = sprintf('%s: %s', obj.AppName, titleStr );
        end
        
        function customizeFigure(obj)
            
            if strcmp(obj.mode, 'standalone')
                figurePos = obj.initializeFigurePosition();         
                obj.Figure.Position = figurePos;
                obj.Panel.Position(3:4) = figurePos(3:4); %Todo: Set this automatically through callbacks
                obj.Panel.Units = 'normalized';
                        
                obj.Figure.CloseRequestFcn = @obj.quitApp;

            else
                %figurePos = getpixelposition(obj.Panel);
            end
                        
            obj.setFigureName()
            
        end            
            
        function createAxes(obj)
            
            panelPos = getpixelposition(obj.Panel);
            axesSize = panelPos(3:4) - [sum(obj.Margins([1,3])), sum(obj.Margins([2,4]))];
            axPosition = [obj.Margins(1:2), axesSize];
            
            
            % Create event axes second. This must be just above main axes
            obj.EventAxes = axes('Parent', obj.Panel, 'Units', 'pixel');
            hold(obj.EventAxes, 'on')
            %obj.EventAxes.Visible = 'off';
            obj.EventAxes.YLim = [0,1];
            obj.EventAxes.XAxis.Visible = 'off';
            obj.EventAxes.YAxis.Visible = 'off';
            
            obj.ax = axes('Parent', obj.Panel, 'Units', 'pixel', 'Position', axPosition );

            %obj.ax.ButtonDownFcn = {@obj.interactiveFrameChangeRequest, 'mousepress' };
            
%             obj.ax.Position(2) = obj.ax.Position(2) + 0.03;
%             obj.ax.Position(4) = obj.ax.Position(4) - 0.03;
            

            obj.ax.UIContextMenu = uicontextmenu(obj.Figure);
            obj.ax.Color = 'none';
            
            obj.createPlotContextMenu(obj.ax.UIContextMenu);
            
            obj.hContextMenu = obj.ax.UIContextMenu;
            
            hold(obj.ax, 'on')
            

            
            % Link properties of eventaxes and signalaxes.
            props = {'XLim', 'Position'};
            obj.AxesLinkObject = linkprop( [obj.ax, obj.EventAxes], props);
            

%             switch 2
%                 case 1
            % Turn of all axes automodes...
% % %             obj.ax.ALimMode = 'manual';
% % %             obj.ax.CLimMode = 'manual';
% % %             
% % %             obj.ax.DataAspectRatioMode = 'auto';
% % %             obj.ax.PlotBoxAspectRatioMode = 'auto';
% % %             
% % %             obj.ax.TickDirMode = 'manual';
% % %             
% % %             obj.ax.XLimMode = 'manual';
% % %             obj.ax.XTickLabelMode = 'auto';
% % %             obj.ax.XTickMode = 'auto';
% % %             
% % %             obj.ax.YLimMode = 'manual';
% % %             obj.ax.YTickLabelMode = 'manual';
% % %             obj.ax.YTickMode = 'manual';
% % %             
% % %             obj.ax.ZColorMode = 'manual';
% % %             obj.ax.ZLimMode = 'manual';
% % %             obj.ax.ZTickLabelMode = 'manual';
% % %             obj.ax.ZTickMode = 'manual';
            
% %                 case 2
            obj.ax.BusyAction = 'cancel'; % todo..
% %             
% %             obj.ax.Interactions = [];
% %             obj.ax.Toolbar = [];
% %             end
             
        end
        
        function createInteractionAxes(obj)
            
            obj.InteractionAxes = axes('Parent', obj.Panel);
            obj.InteractionAxes.Units = 'pixel';
            obj.InteractionAxes.Position = obj.ax.Position;
            obj.InteractionAxes.HandleVisibility = 'off';
            obj.InteractionAxes.Visible = 'off';
            
            hold(obj.InteractionAxes, 'on')
            
            obj.InteractionAxes.XTick = [];
            obj.InteractionAxes.YTick = [];
            obj.InteractionAxes.YLim = [0,1];
            obj.InteractionAxes.Tag = 'SignalViewer Interaction Axes';
            
            hlink = linkprop([obj.ax, obj.InteractionAxes], {'XLim', 'Position'});
            obj.InteractionAxes.UserData = hlink;
            
        end
        
        function createScrollbar(obj)
            
            panelWidth = obj.ax.Position(3);
            panelHeight = obj.ax.Position(4);
            
            obj.hScrollPanelX = uipanel('Parent', obj.Panel, 'Units', 'pixel', 'Position', ...
                [obj.Margins(1), 5, panelWidth, 10]);
                 
            xLoc = obj.Figure.Position(3) - obj.Margins(3) - 10;
            xLoc = obj.Figure.Position(3) - 15;
            obj.hScrollPanelY = uipanel('Parent', obj.Panel, 'Units', 'pixel', 'Position', ...
                [xLoc, obj.Margins(2), 10, panelHeight]);
            
            
            obj.hScrollPanelX.BorderType = 'none';
            obj.hScrollPanelY.BorderType = 'none';
            
            obj.hScrollbarX = uim.widget.scrollerBar(obj.hScrollPanelX, 'BarColor', ones(1,3)*0.7, 'Visible', 'off');
            obj.hScrollbarY = uim.widget.scrollerBar(obj.hScrollPanelY, 'BarColor', ones(1,3)*0.7, 'Visible', 'off', 'Direction', 'reverse');

%             obj.hScrollbarX.TrackColor = ones(1,3)*0.9;

            obj.hScrollbarX.Callback = @obj.setXLimitsScrollbar;
            obj.hScrollbarX.StopMoveCallback = @obj.onScrollStop;
            obj.hScrollbarX.showTrack()
            obj.hScrollbarX.TrackColor = ones(1,3);
            obj.hScrollbarX.VisibleAmount = 1;
            
            obj.hScrollbarY.Callback = @obj.setYLimitsScrollbar;
            %obj.hScrollbarY.StopMoveCallback = @obj.onScrollStop;
            obj.hScrollbarY.hideTrack()
            obj.hScrollbarY.TrackColor = ones(1,3);
            obj.hScrollbarY.VisibleAmount = 1;
            
        end
        
        function setFigureName(obj)

            isValidFigure = ~isempty(obj.Figure) && isvalid(obj.Figure);

            if isValidFigure && strcmp(obj.mode, 'standalone')

                figureName = sprintf('%s (%d)', obj.AppName, ...
                            obj.Figure.Number );

                obj.Figure.Name = figureName;
            end
        end

        function createPlotContextMenu(obj, m)
            
            mitem = uimenu(m, 'Label', 'Edit Settings', 'Callback', @obj.editSettings);
            mitem = uimenu(m, 'Label', 'Show Legend', 'Callback', @obj.showLegend);
            mitem = uimenu(m, 'Label', 'Show Signals');
            
        end

        function resetContextMenuSignalsToShow(obj, names)
            
            mItem = findobj(obj.hContextMenu, 'Label', 'Show Signals');
            
            delete(mItem.Children)

        end

        function updateContextMenuSignalsToShow(obj, names)
            
            mItem = findobj(obj.hContextMenu, 'Label', 'Show Signals');
            
            for i = 1:numel(names)

                h = uimenu(mItem, 'Label', names{i}, 'Checked', 'on');
                h.Callback = @obj.onSignalsToShowChanged;
            end

        end
        
        function [axis, location] = isPointOnAxis(obj, xy)
        %isPointOnAxis Check if point is on axis of axes.
        %
        %   Return which axis ('x' or 'y') and location ('top', 'bottom'
        %   or 'left', 'right')
        %
        %   INPUTS:
        %       xy : vector (optional) of point coordinates in pixels,
        %         relative to figure's reference point (lower left corner).
        %         If no value is given, the value of the figure's 
        %         CurrentPoint property is used.
        %
        %   OUTPUT
        %       axis: axis if point is on one of the axis ('x' or 'y')
        %       location : ('top', 'bottom' or 'left', 'right')
        
        %   Note: this function needs more work to be generalized
        %       Use axes inner and outerposition to get axis positions?


            % Initialize output variables.
            axis = '';
            location = '';

            if nargin < 2
                xy = obj.Figure.CurrentPoint;
            end
            
            figPos = getpixelposition(obj.Panel, true);
            axPos = getpixelposition(obj.ax, true);

            
            if ~isempty( obj.hScrollPanelX )
                scrollPos = getpixelposition(obj.hScrollPanelX, true);
                if xy(1) > scrollPos(1) && xy(1) < sum(scrollPos([1,3]))
                    if xy(2) > scrollPos(2) && xy(2) < sum(scrollPos([2,4]))
                        return
                    end
                end
            end
            %axPos = obj.ax.Position;
            
            % Determine if point is anywhere outside the axes but still
            % within the panel.
            isOnLeftSide = xy(1) > figPos(1) && xy(1) < axPos(1);
            isOnBottom = xy(2) > figPos(1) && xy(2) < axPos(2);
            isOnRightSide = xy(1) > sum(axPos([1,3])) && xy(1) < figPos(3);
            isOnTop = xy(2) > sum(axPos([2,4])) && xy(2) < figPos(4);
            
            if isOnLeftSide && ~ (isOnBottom || isOnTop)
                axis = 'y';
                location = 'left';
            
            elseif isOnRightSide && ~ (isOnBottom || isOnTop)
                if numel(obj.ax.YAxis)==2
                    axis = 'y';
                    location = 'right';
                end
            elseif isOnBottom && ~(isOnLeftSide || isOnRightSide)
                axis = 'x';
                location = 'bottom';
            elseif isOnTop && ~(isOnLeftSide || isOnRightSide)
                if numel(obj.ax.XAxis)==2
                    axis = 'x';
                    location = 'top';
                end
            end
            
            if nargout == 1
                clear location
            end
            
        end
       
        function tsInd = isPointInEventVector(obj, pointX )
            
            tsInd = [];
            
            if isa(obj.tsArray, 'timetable')
                return
            end
            
            isEvent = arrayfun(@(x) islogical(x.Data), obj.tsArray );
            matchedInd = find(isEvent);
            
            for i = fliplr(matchedInd)
                
                if pointX < 1 || pointX > numel(obj.tsArray(i).Data)
                    continue
                end
                
                isPointInData = obj.tsArray(i).Data(round(pointX));
                if isPointInData
                    tsInd = i;
                end
            end
            
        end

        function S = gatherEventData(obj, ind, xPoint)
            
            % Get data of time series to edit
            tmpData = obj.tsArray(ind).Data;

            % Find coordinates where data should be edited
            [evtStart, evtStop] = utility.findTransitions(tmpData);
            evtInd = find( xPoint > evtStart & xPoint < evtStop );
            modifiedInd = evtStart(evtInd):evtStop(evtInd);
            
            % Add indices to the userdata property
            obj.tsArray(ind).UserData.ModifiedEventInd = modifiedInd;
            tmpData(modifiedInd) = false;
            obj.tsArray(ind).Data = tmpData;
            
            % Replace plotdata.
            plotColor = obj.hlineTsArray(ind).FaceColor;
            delete(obj.hlineTsArray(ind))
            hPatch = signalviewer.plot.patchEvents(obj.EventAxes, tmpData, plotColor, [0,1]);
            hPatch.FaceAlpha = 0.3;
            obj.hlineTsArray(ind) = hPatch;
                                
            S.TimeSeriesIndex = ind;
            S.XCoordinates = modifiedInd;
        end
        
        function onEventVectorChanged(obj, ~, evtData)
            
            tsIdx = evtData.TimeSeriesIndex;
            
            % Update event data
            newData = obj.tsArray(tsIdx).Data;
            newData(obj.tsArray(tsIdx).UserData.ModifiedEventInd) = false;
            newData(evtData.XCoordinates) = true;
            
            % Update the timeseries object
            obj.tsArray(tsIdx).Data = newData;
            obj.tsArray(tsIdx).UserData.ModifiedEventInd = [];
            
            % Replace plotdata.
            plotColor = obj.hlineTsArray(tsIdx).FaceColor;
            delete(obj.hlineTsArray(tsIdx))
            hPatch = signalviewer.plot.patchEvents(obj.EventAxes, newData, plotColor, [0,1]);
            hPatch.FaceAlpha = 0.3;
            obj.hlineTsArray(tsIdx) = hPatch;
            
        end
        
    end
    
    methods (Access = protected) % Time series initialization and updating

        function tsArray = parseTimeSeriesArray(obj, tsArray, varargin)
            
            % Returns tsArray if requested
            
            if isa(tsArray, 'timetable')
                %pass
                varNames = tsArray.Properties.VariableNames;
                
            elseif isa(tsArray, 'timeseries')
                varNames = {tsArray.Name};

            elseif ~isa(tsArray, 'timeseries')
                tsArray = obj.createTimeseriesArray(tsArray, varargin{:});
                varNames = {tsArray.Name};

            end
            
            obj.tsNames = [obj.tsNames, varNames];
            
            % Append timeseries array to prop.
            if isempty(obj.tsArray)
                obj.tsArray = tsArray;
            else
                obj.tsArray = [obj.tsArray, tsArray];
            end
            
            % TODO: set this based on
            if isa(tsArray, 'timeseries')
                obj.nSamples = max( arrayfun(@(ts) ts.Length, obj.tsArray) );
            elseif isa(tsArray, 'timetable')
                obj.nSamples = size(obj.tsArray, 1);
            else
                error('Unsupported')
            end
            
            obj.updateContextMenuSignalsToShow( varNames )

            
            if ~nargout
                clear tsArray
            end
            
        end
        
        function tsArray = createTimeseriesArray(obj, data, varargin)

            if isa(data, 'cell')

                for i = 1:numel(data)
                   if isrow( data{i} )
                       data{i} = transpose(data{i});
                   end
                end

                tsArray = cellfun(@(v) timeseries(v), data);
            elseif isa(data, 'timeseries')
                tsArray = data;
            elseif isrow(data) 
                tsArray = timeseries(data');
            elseif iscolumn(data)
                tsArray = timeseries(data);
            else
                tsArray = timeseries(data);
            end
            
            
            if contains(varargin(1:2:end), 'Name')
                match = find( contains(varargin(1:2:end), 'Name') );
                names = varargin{match+1};
                if ~isa(names, 'cell')
                    names = {names};
                end
                for i = 1:numel(tsArray)
                    tsArray(i).Name = names{i};
                end
            end
            
        end
        
        function addTimeSeriesArray(obj, tsArray, varargin)
            
            obj.tsNames = {tsArray.Name};
            obj.tsArray = tsArray;
            
            obj.nSamples = tsArray(1).Length;
            
        end
        

        

% %         function data = subsref(obj, S)
% %             
% %             switch S(1).type
% % 
% %                 % Use builtin if a property is requested.
% %                 case '.'
% %                     if isempty(obj.tsNames) || ~any( contains(obj.tsNames, S(1).subs) )
% %                         
% %                         if any(strcmp(S(1).subs, {'interactiveFrameChangeRequest'}))
% %                             builtin('subsref', obj, S)
% %                         else
% %                             try
% %                                 data = builtin('subsref', obj, S);
% %                             catch
% %                                 builtin('subsref', obj, S)
% %                             end
% %                             
% %                             % alternative:
% %                             %data = cell(1,4);
% %                             %[data{:}] = builtin('subsref', obj, S)
% %                         end
% %                         
% %                         return
% %                     else
% %                         ind = find(contains(obj.tsNames, S(1).subs));
% %                         if numel(S) == 1
% %                             data = obj.hlineTsArray(ind);
% %                         elseif numel(S) > 1 && strcmp(S(2).type, '()')
% %                             data = obj.tsArray(ind).Data(S(2).subs{1});
% %                         else
% %                             data = builtin('subsref', obj, S);
% %                         end
% % 
% %                     end
% %                 otherwise
% %                     data = builtin('subsref', obj, S);
% %             end
% %             
% %             
% %         end
% %         
% %         
% %         function obj = subsasgn(obj, S, B)
% %             
% % 
% %             switch S(1).type
% % 
% %                 % Use builtin if a property is requested.
% %                 case '.'
% %                     if ~any( contains(obj.tsNames, S(1).subs) )
% %                         obj = builtin('subsasgn', obj, S, B);
% %                         return
% %                     else
% %                         ind = find(contains(obj.tsNames, S(1).subs));
% %                         
% %                         if strcmp(S(2).type, '()')
% %                             obj.tsArray(ind).Data(S(2).subs{1}) = B;
% %                             obj.hlineTsArray(ind).YData(S(2).subs{1}) = B;
% %                         else
% %                             obj = builtin('subsasgn', obj, S, B);
% %                         end
% % 
% %                     end
% %                 otherwise
% %                     obj = builtin('subsasgn', obj, S, B);
% %             end
% % 
% %             
% %         end
% %         
% %     
    end

    methods (Access = public) % Data access and update
        
        function h = getHandle(obj, name, number)
            %Todo: Isthis to naive???
            
            h = [];
            
            ind = strcmp(obj.tsNames, name);
            
            if isempty(ind); return; end
            
            try
                h = obj.hLineArray.(name);
            catch
                h = obj.hlineTsArray(ind);
            end
            
            if nargin >= 3
                h = h(1:number);
            end
            
        end
        
        function ts = getTimeSeries(obj, name)
            
            ts = [];
            ind = contains(obj.tsNames, name);
            if isempty(ind); return; end
            ts = obj.tsArray(ind);
            
        end
        
        function updateLineData(obj, timeseriesName, newYData, newXData)
        %updateLineData Update line data for a specified timeseries
        
            if nargin < 4; newXData = []; end
            
            if iscolumn(newYData); newYData = transpose(newYData); end
            if iscolumn(newXData); newXData = transpose(newXData); end

            hLine = obj.getHandle(timeseriesName);
            
            oldYData = hLine.YData;
            isUpdated = oldYData ~= newYData;
            hLine.YData(isUpdated) = newYData(isUpdated);
            
            if ~isempty(newXData)
                oldXData = hLine.YData;
                isUpdated = oldXData ~= newXData;
                hLine.XData(isUpdated) = newXData(isUpdated);
            end

        end
        

        function tf = onSignalsToShowChanged(obj, src, evt)
            
            signalName = src.Label;
                        
            if strcmp( src.Checked, 'on' )
                visible = false;
            else
                visible = true;
            end
            
            obj.onSignalVisibilityChanged(signalName, visible)
            
            if nargout
                tf = logical(visible);
            end
        end
        
        function onSignalVisibilityChanged(obj, signalName, newState)
            
            % Todo: if multiple lines are present in a handle, should only
            % change the visibility of lines that should be visible...
            
            hMenu = findobj(obj.hContextMenu, 'Label', 'Show Signals');
            mItem = findobj(hMenu, 'Label', signalName);

            h = obj.getHandle(signalName);
            
            if nargin < 3
                newState = ~ h(1).Visible;
            end
            
            if newState
                set(obj.ax.YAxis, 'LimitsMode', 'auto')
                mItem.Checked = 'on';
                set(h, 'Visible', 'on');
                set(obj.ax.YAxis, 'LimitsMode', 'manual')
            else
                mItem.Checked = 'off';
                set(h, 'Visible', 'off');
            end
            
            drawnow


        end
        
        
        
        function editSettings(obj, ~, ~)
        
            oldSettings = obj.settings;
            newSettings = tools.editStruct(oldSettings, 'all', ...
                'Signal Viewer Settings', 'Callback', @obj.onSettingsChanged);
            obj.settings = newSettings;
            
            
            
        end
        
        function onSettingsChanged(obj, name, value)

            switch name
                case 'DataPointPerPixel'
                    if ~isempty(obj.TimeseriesPyramid)
                        obj.TimeseriesPyramid.DataPointPerPixel = value;
                        obj.updateDownsampledData()
                    end
            end
            
        end
        
        function h = plotTimeSeries(obj, tsArray)
            
% %             if contains(varargin(1:2:end), 'Color')
% %                 isMatch = contains(varargin(1:2:end), 'Color');
% %                 colors = varargin(find(isMatch)+1);
% %             end

            persistent colorInd
            if isempty(colorInd); colorInd = 0; end
    
            nTimeseries = numel(tsArray);
            
            h = cell(nTimeseries, 1);
            
            colors = get(obj.Axes, 'ColorOrder');
            nColors = size(colors,1);
            
            %colors = viridis(nColors);
            %patchColors = colors;
            %colors = cbrewer('qual', 'Set2', nColors, 'spline');
            %patchColors = cbrewer('seq', 'PuBuGn', nColors*2, 'spline');
            %patchColors = patchColors(nColors+1:end, :);
            
            patchColors = cbrewer('qual', 'Set2', max([nColors,3]), 'spline'); % Should be min 3 for cbrewer
            
            for i = 1:numel(tsArray)
                colorInd = mod(colorInd, nColors) + 1;
                
                if islogical(tsArray(i).Data)
                    if sum(tsArray(i).Data) == 0
                        tsArray(i).Data(1) = true; % Hack to avoid crash if vector contains no events
                    end
                    
                    c = mod(i-1, nColors)+1;
                    hNew = signalviewer.plot.patchEvents(obj.EventAxes, tsArray(i).Data(:), patchColors(colorInd,:), [0,1]);
                    hNew.FaceAlpha = 0.3;
                    
                elseif size(tsArray(i).Data, 2) > 100
                    hNew = image(obj.ax, tsArray(i).Data');
                    hNew.CDataMapping = 'scaled';
                    obj.ax.YLim = [1,size(tsArray(i).Data,2)];
                    obj.ax.XLim = [1,size(tsArray(i).Data,1)];
                    obj.ax.CLim = [prctile( tsArray(i).Data(:), 0.5 ), ...
                        prctile( tsArray(i).Data(:), 99.5 ) ];
                else
                    %hNew = plot(obj.ax, nan, nan);
                    hNew = line(obj.ax, tsArray(i).Time, tsArray(i).Data, 'Visible', 'on', 'Color', colors(colorInd,:) );
                end

                if i == 1; hold(obj.ax, 'on'); end
                
                
                set(hNew, 'HitTest', 'off', 'PickableParts', 'none')
                
                
                h{i} = hNew;

            end
            
%             plot_darkmode()
%             obj.ax.Color = 'none';
            
            switch obj.ActiveYAxis
                case 'left'
                    obj.YLimExtreme.left = obj.ax.YLim;
                case 'right'
                    obj.YLimExtreme.right = obj.ax.YLim;
            end

            try % Todo: Fix this...
                set(cat(1, h{:}), 'LineWidth', 1)
            end
            
            set(cat(1, h{:}), 'PickableParts', 'none', 'HitTest', 'off')
            
            % Add lines to plot data property. Todo: streamline with
            % roisignalviewer
            hLines = cat(1, h{:});

            if isempty(obj.hlineTsArray)
                obj.hlineTsArray = hLines;
            else
                obj.hlineTsArray(end+1:end+numel(hLines)) = hLines;
            end

            if nargout == 0
                clear h
            end
            
        end
        
        function h = plotTimeTable(obj, timetableObj)
                
            persistent colorInd
            if isempty(colorInd); colorInd = 0; end
    
            numTimepoints = size(timetableObj, 1);
            numTimeseries = size(timetableObj, 2);
            
            sampleIdx = 1:size(timetableObj, 1);
            
            reso = obj.settings.DataPointPerPixel;
            if signalviewer.TimeseriesPyramid.useDownsampling(numTimepoints, reso)
                
                % Todo: This should be done according to single/multitrace
                % state....
                yData = timetableObj.Variables;
                yData = yData - prctile(yData, 25, 1); % Todo: keep these as persistent variables??
                yData = yData ./ prctile(yData(:), 99.9);
                timetableObj.Variables = yData;
                
                obj.TimeseriesPyramid = signalviewer.TimeseriesPyramid(timetableObj, reso);
                addlistener(obj.ax, 'XLim', 'PostSet', @obj.updateDownsampledData);
                [sampleIdx, timetableObj] = obj.TimeseriesPyramid.getData(sampleIdx([1,end]));
            end
            
            h = cell(numTimeseries, 1);
            
            colors = get(gca,'ColorOrder');
            nColors = size(colors,1);
            
            for i = 1:numTimeseries
                             
                colorInd = mod(colorInd, nColors) + 1;
            
                thisTimeseries = timetableObj(:, i);
                dataValues = thisTimeseries.Variables;
                
                
                numSeries = size(dataValues, 2);
                
                if numSeries > 1
                    
                    thisData = thisTimeseries.Variables;
                    thisData = thisData - prctile(thisData, 25, 1);
                    thisData = thisData ./ prctile(thisData(:), 99.9);
                    thisData = thisData + (1:numSeries);
                    
                    baseColor = colors(colorInd,:);
                    baseColorHsv = rgb2hsv(baseColor);
                    
                    colorMapHsv = repmat(baseColorHsv, numSeries, 1); 
                    colorMapHsv(:, 3) = linspace(0.5, 1, numSeries);
                    colorMap = flipud( hsv2rgb(colorMapHsv) );
                    
                    hNew = line(obj.ax, sampleIdx, thisData, ...
                        'Visible', 'on', 'Color', colors(colorInd,:) );
                    
                    set(hNew, {'Color'}, arrayfun(@(i) colorMap(i,:), 1:numSeries, 'uni', 0)')
                
                    varName = thisTimeseries.Properties.VariableNames{1};
                    obj.hLineArray(1).(varName) = hNew;
                
                else
                    
                    hNew = plot(obj.ax, sampleIdx, thisTimeseries.Variables, ...
                        'Visible', 'on', 'Color', colors(colorInd,:) );
                end

                set(hNew, 'HitTest', 'off', 'PickableParts', 'none')

            end
            

            
            switch obj.ActiveYAxis
                case 'left'
                    obj.YLimExtreme.left = obj.ax.YLim;
                case 'right'
                    obj.YLimExtreme.right = obj.ax.YLim;
            end
        end
        
        function updateDownsampledData(obj, src, evt)
            % Todo: Update specific variables...
            newLim = obj.ax.XLim;

            persistent oldLim
            if isempty(oldLim); oldLim = [1, obj.nSamples]; end
            
            isInsideLimits = newLim(1) >= oldLim(1) && newLim(2) <= oldLim(2);

            % Calculate limits that are larger than the current view...
            newLim = newLim + [-1, 1].*range(newLim)*0.5;
            newLim(1) = max(1, newLim(1));
            newLim(2) = min(obj.nSamples, newLim(2));
            
            level = obj.TimeseriesPyramid.getLevel(newLim);
            requiresResampledData = level ~= obj.TimeseriesPyramid.CurrentLevel;
            
            if isInsideLimits && ~requiresResampledData
                return
            end
            
            %tic
            [sampleIdx, timetableObj] = obj.TimeseriesPyramid.getData( newLim );

            varNames = timetableObj.Properties.VariableNames;
            for i = 1:numel(varNames)
            
                yData = double( timetableObj.(varNames{i}) );
            
                numSamples = size(yData, 1);
                numSeries = size(yData, 2);
                
                % Todo: get subset of series.
                
                % Stack series vertically.
                yData = yData + (1:numSeries);
            
% %             % Update plot v3 (Fastest, but requires a rewrite)
% %             xData_ = repmat(sampleIdx', 1, numSeries);
% %             xData_(end, :) = nan;
% %             yData_ = yData;
% %             yData_(end, :) = nan;
% %             set( obj.hLineArray.dff(1), 'XData', xData_(:), 'YData', yData_(:))
% % % %             set( obj.hLineArray.dff(1), 'Color', obj.hLineArray.dff(end).Color )
% % % %             for i = 2:numSeries
% % % %                 set( obj.hLineArray.dff(i), 'XData', nan, 'YData', nan);
% % % %             end
            

                % Update plot (v1)
                xData = repmat({sampleIdx}, numSeries, 1);
                yData = mat2cell(yData, numSamples, ones(numSeries,1))';
                set( obj.hLineArray.(varNames{i}), {'XData'}, xData, {'YData'}, yData )

    % %         % Update plot (v2) Consistently about 50% slower
    % %             for i = 1:size(yData, 2)
    % %                 set( obj.hLineArray.dff(i), 'XData', sampleIdx, 'YData', yData(:,i));
    % %             end
                %toc

                oldLim = newLim;
                drawnow

                %obj.TimeseriesPyramid.CurrentLevel
            end
            
        end
        
        function addTimeseries(obj, timeseriesData, varargin)
        %addTimeseries Add timeseries to plot.
        
            % Create timeseries if data is passed as normal array
            tsArray = obj.createTimeseriesArray(timeseriesData, varargin{:});
            obj.updateContextMenuSignalsToShow({tsArray.Name})

            numNew = numel(tsArray);
            
            % Todo/ToResolve: Can time series be combined in an array if
            % they dont have the same amount of samples?
            
            obj.tsNames(end+1:end+numNew) = {tsArray.Name};
            obj.tsArray(end+1:end+numNew) = tsArray;
            
            obj.plotTimeSeries(tsArray)
            
        end
        
        function deleteTimeseries(obj, timeseriesName)
            
            isMatch = find(contains({obj.tsArray.Name}, timeseriesName));
            
            delete(obj.hlineTsArray(isMatch));
            obj.hlineTsArray(isMatch) = [];
            obj.tsArray(isMatch) = [];
            obj.tsNames(isMatch) = [];
            
        end
        
        function updateTimeSeries(tsArray)
            
            
        end
        
        function updatePlot()
            
  
        end
        
        function colorLines(obj)
            
            isLines = arrayfun(@(h) isa(h, 'matlab.graphics.chart.primitive.Line'), obj.hlineTsArray);
            nLines = numel(obj.hlineTsArray(isLines));
            
            colorScheme = 'cbrewer';
            switch colorScheme
                case 'cbrewer'
                    nRepeats = ceil(nLines/5);
                    colorSelection = {'Blues', 'Greens', 'Oranges', 'Reds', 'Purples'};
                    
                    shades = linspace(5,10, nRepeats);
                    
                    % Add different colors to a cell array
                    cmaps = cellfun(@(cs) cbrewer('seq', cs, 15, 'spline'), colorSelection, 'uni', 0);
                    plotColor = cell(1, nLines);
                    
                    
                    c = 1;
                    for iShade = shades
                        for jColorInd = 1:numel(colorSelection)
                            plotColor{c} = cmaps{jColorInd}(iShade, :);
                            c = c+1;
                        end
                    end
                    plotColor = plotColor(1:nLines);
                    
                    
                case 'viridis'
            
                    colorMap = viridis(nLines);
                    plotColor = arrayfun(@(i) colorMap(i,:), 1:nLines, 'uni', 0);
            end

        
            set(obj.hlineTsArray(isLines)', {'Color'}, plotColor')
            
        end

        function axH = getAxes(obj)
            axH = obj.ax;
        end
        
        function interactiveFrameChangeRequest(obj, source, event, action)

            if strcmp(obj.Panel.Visible, 'off') 
                return
            end
            
            switch action
                case 'mousescroll'
                    if ~obj.isMouseInApp; return; end

                    i = event.VerticalScrollCount .* obj.settings.ScrollFactorPanX;
                    
                case 'mousepress'
% %                     if event.Button == 3 % Right click
% %                         return
% %                     end
                    
                    newValue = event.IntersectionPoint(1);                    
                    i = round( newValue -  obj.currentFrameNo );
                    
                case {'slider', 'buttonclick'}
                    newValue = source.Value;
                    i = newValue -  obj.currentFrameNo;
                    i = round(i);

                case {'jumptoframe'}
                    
                    newFrame = source.String;
                    if isa(newFrame, 'char'); newFrame = str2double(newFrame); end
                    i = newFrame -  obj.currentFrameNo;
                    i = round(i);
                    
                case 'prev'
                    i = -1;
                case 'next'
                    i = 1;
                    
                otherwise
                    i = 0;
            end
            
            if ~exist('newValue', 'var')
                newValue = obj.currentFrameNo + i;
            end
            
                        
            if i ~= 0 && newValue >= 1 && newValue <= obj.nSamples
                obj.changeFrame(obj.currentFrameNo + i, action)
            end
            
        end

        function changeFrame(obj, newFrame, action)
            
            if nargin < 3; action = ''; end
            
            obj.currentFrameNo = newFrame;
            
            % Update linked apps!
            if ~isempty(obj.LinkedApps)
                for i = 1:numel(obj.LinkedApps)
                    % Todo: Make sure the property is available....
                    obj.LinkedApps(i).currentFrameNo = obj.currentFrameNo;
                end
            end
            
        end
        
        function onFrameChanged(obj, incr)
            
            obj.updateFrameMarker()
            
            % Pan along axes in signalPlot if zoom is on
            if ~isequal(obj.ax.XLim, [1, obj.nSamples])
                %if ~contains(action, {'mousepress'})
                    obj.setXLimitsPan(obj.ax.XLim + incr)
                %end
            end
            
            %drawnow
            
        end
        
        function updateFrameMarker(obj, flag)
        % Update line indicating current frame in plot.
        
% %             persistent tA tB i
% %             if isempty(tA)
% %                 [tA, tB, i] = deal(0)
% %             end
                       
            if ~obj.isConstructed; return; end

        
            if nargin < 2; flag = 'update_x'; end
        
            
            frameNo = obj.currentFrameNo;
            if isempty(obj.hlineCurrentFrame) || ~all(isgraphics(obj.hlineCurrentFrame))
                obj.hlineCurrentFrame = plot(obj.InteractionAxes, [1, 1], [0,1], '-', 'HitTest', 'off');
                
                obj.hlineCurrentFrame(2) = plot(obj.InteractionAxes, 1, 1, 'v', 'HitTest', 'off');
                obj.hlineCurrentFrame(3) = plot(obj.InteractionAxes, 1, 0, '^', 'HitTest', 'off');
                
                set(obj.hlineCurrentFrame, 'Color', ones(1,3) * 0.4, 'MarkerFaceColor', ones(1,3) * 0.4);
                set(obj.hlineCurrentFrame, 'Tag', 'FrameMarker');
                set(obj.hlineCurrentFrame(1), 'Color', [ones(1,3)*0.4, 0.6])
                set(obj.hlineCurrentFrame, 'HandleVisibility', 'off')
%             elseif isequal(flag, 'update_y')
            else
                %yLim = obj.ax.YAxis(1).Limits;
                
                yData = {[0,1], 1, 0};
                xData = {[frameNo, frameNo], frameNo, frameNo};
                set(obj.hlineCurrentFrame, {'XData'}, xData', {'YData'}, yData')

            end
        end
        
        
        
% % % %  Methods for changing x axis limits
%       Todo: Move to pointermanager.
        
        function plotZoom(obj, direction, speed, axis)

            if nargin < 3 || isempty(speed); speed = 10; end
            if nargin < 4; axis = 'x'; end
            % Todo: figure out how to set scroll sensitivity.
            
            
            % Get current mouse position
            mp_a = get(obj.ax, 'CurrentPoint');
            mp_a = mp_a(1, 1:2);
                        
            
            % Get limits of selected axis.
            switch axis
                case 'x'
                    oldLim = obj.ax.XLim;
                    centerPoint = mp_a(1);
                case 'y'
                    oldLim = obj.ax.YLim;
                    centerPoint = mp_a(2);
            end
            
            
            % Determine new limits.
            oldCenter = mean(oldLim);

            switch direction
                case 'in'
                    newRange = diff(oldLim) * max([0.3,  1-(speed*0.1)]); % (0.9) ;% + 0.01/speed
                case 'out'
                    newRange = diff(oldLim) / max([0.3,  1-(speed*0.1)]);% + 0.01/speed) ;
            end
            
%             fprintf('newRange: %05d\n', round(newRange(1)) )
            
            % Fix an issue where, if you zoom in too closely in x, you
            % cannot zoom back out...
            switch axis
                case 'x'
                    newWidth = mean([1, newRange]);
                case 'y'
                    newWidth = newRange./2;
            end
            
            
            newLim = [oldCenter-newWidth, oldCenter+newWidth];
            
            % Calculate shift for good zoom in on current point
            % % x0 = obj.currentFrameNo;
            newMin = -1 * ((centerPoint-oldLim(1)) / diff(oldLim) * diff(newLim) - centerPoint);
            correctionShift = newLim(1) - newMin;
            newLim = newLim - correctionShift;

            
            switch axis
                case 'x' % Zoom in or out on xaxis

                    % Change frame so that zooming happens on mousepoint
                    if obj.currentFrameNo ~= round(centerPoint)
                        obj.interactiveFrameChangeRequest(struct('String', num2str(round(centerPoint))), [], 'jumptoframe')
                    end

                    obj.setXLimitsZoom(newLim)
                    
                case 'y'
                    
                    obj.setYLimitsZoom(newLim)
            end

%             fprintf('xMin: %05d - xMax: %05d\n', round(xLimNew(1)), round(xLimNew(2)))

        end
        
        function setYLimitsZoom(obj, newLimits)
            
            absLimits = obj.YLimExtreme.(obj.ActiveYAxis);
            
            if newLimits(1) < absLimits(1)
                newLimits(1) = absLimits(1);
            end
            
            if newLimits(2) > absLimits(2)
                newLimits(2) = absLimits(2);
            end   
            
            
            obj.ax.YLim = newLimits;
            %obj.updateFrameMarker('update_y')
            
            % Todo: Update ydata of all patches....
            
            
        end
        
        function setXLimitsZoom(obj, newLimits)
        % Specify newLimits in frames
            
            absLimits = [1, obj.nSamples];
            oldLimits = obj.ax.XLim;
            
            % Sanity checks
            if isequal(oldLimits, newLimits)
                return
            elseif newLimits(2) < newLimits(1)
                return
            end
            
            newLimits = round(newLimits);
            
            % Check that limits are within absolute limits (force if not)
            if newLimits(1) < absLimits(1)
                newLimits(1) = absLimits(1);
            end
            
            if newLimits(2) > absLimits(2)
                newLimits(2) = absLimits(2);
            end
                        
            % Current frame should remain in the image, preferably in the
            % center. So I will check if the new limits have to be shifted.
            
%             % Find maximum shift allowed... 
%             maxShiftLeft = absLimits(1) - newLimits(1);
%             maxShiftRight = absLimits(2) - newLimits(2);
%             
%             % Find shift to put current frame in center
%             shift = obj.currentFrameNo - round(mean(newLimits));
%             
%             % Don' allow values for shift outside max limits.
%             if shift < maxShiftLeft
%                 shift = maxShiftLeft;
%             elseif shift > maxShiftRight
%                 shift = maxShiftRight;
%             end
%             
%             % Shift the new limits
%             newLimits = newLimits + shift;
            
            % Set new limits
            obj.setNewXLims(newLimits)
        end
    
        function setXLimitsScrollbar(obj, src, ~)
            
            newValue = src.Value;
            
            xLimRange = range(obj.ax.XLim);
            xLimExtreme = [1, obj.nSamples];
            
            newXLimStart = round(xLimExtreme(2)-xLimRange) .* newValue;
            
            newXLimEnd = newXLimStart + xLimRange;
            
            if newXLimEnd > xLimExtreme(2)
                newXLimEnd = xLimExtreme(2);
                newXLimStart = newXLimEnd-xLimRange;
            end
             
            obj.setNewXLims([newXLimStart,newXLimEnd])
                        
        end
       
        function setYLimitsScrollbar(obj, src, ~)
            
            newValue = src.Value;
            
            yLimRange = range(obj.ax.YLim);
            
            switch obj.ActiveYAxis
                case 'left'
                    yLimExtreme = obj.YLimExtreme.left;
                case 'right'
                    yLimExtreme = obj.YLimExtreme.right;
            end
            
            newYLimStart = round(yLimExtreme(2)+1-yLimRange) .* newValue;
            newYLimEnd = newYLimStart + yLimRange;
            
            if newYLimEnd > yLimExtreme(2)
                newYLimEnd = yLimExtreme(2);
                newYLimStart = newYLimEnd-yLimRange;
            end
             
            obj.setNewYLims([newYLimStart, newYLimEnd])
                        
        end
        
        
        function onScrollStop(obj, ~, ~)
            
            newFrameNo = round(mean(obj.ax.XLim));
            obj.changeFrame(newFrameNo, 'mousepress')
        end
        
        function setXLimitsPan(obj, newLimits)
        % Check that limits are within absolute limits (force if not)
        
        % This is a lot of conditions. Should it be this effin long??
            absLimits = [1, obj.nSamples];
            tmpLimits = obj.ax.XLim;
            
            direction = sign(newLimits(1)-tmpLimits(1));
            changeLimits = true;
            
            % Don't pan if current frame is close to abs limits.
            if obj.currentFrameNo < absLimits(1) + diff(tmpLimits)/2
                changeLimits = false;
            elseif obj.currentFrameNo < absLimits(1) - diff(tmpLimits)/2
                changeLimits = false;
            end
            
            % Don't pan if current frame passed midway of current limits.
            if direction == 1 
                if obj.currentFrameNo < round(diff(tmpLimits)/2 + tmpLimits(1))
                    changeLimits = false;
                end
            elseif direction == -1
                if obj.currentFrameNo > round(diff(tmpLimits)/2 + tmpLimits(1))
                    changeLimits = false;
                end
            else
               return 
            end
            
            % Not necessary in this context, but just for the sake of it.
            if newLimits(1) < absLimits(1) || newLimits(2) > absLimits(2)
                changeLimits = false;
            end
            
            % Change limits.
            if changeLimits
                obj.setNewXLims(newLimits)
            elseif ~changeLimits && obj.currentFrameNo < newLimits(1)
                newLimits = newLimits - (newLimits(1)-obj.currentFrameNo);
                obj.setNewXLims(newLimits)
            elseif ~changeLimits && obj.currentFrameNo > newLimits(2)
                newLimits = newLimits + (obj.currentFrameNo-newLimits(2));
                obj.setNewXLims(newLimits)
            else
                return
            end
            
        end
        
        function setNewXLims(obj, newLimits)
              
% %             if isa(obj.tsArray, 'timetable')
% %                 extremeLimits = obj.tsArray.Time([1,end]);
% %                 obj.tLimExtreme = extremeLimits;
% %             else
% %                 extremeLimits = [1, obj.nSamples];
% %             end
            
            extremeLimits = [1, obj.nSamples];

            
            if nargin == 1 || isempty(newLimits)
                if isa(obj.tsArray, 'timetable')
                    newLimits = extremeLimits;
                else
                    newLimits = obj.firstFrameNo + [0, obj.nSamples-1];
                end
            end
            
% %             if isa(obj.tsArray, 'timetable') && ~isa(newLimits, 'duration')
% %                 newLimits = seconds(newLimits);
% %             end

            % Todo: Make sure XLim2 > XLim1
            newLimits(1) = max([extremeLimits(1), newLimits(1)]);
            newLimits(2) = min([extremeLimits(2), newLimits(2)]);
            
            if diff(newLimits) < 100; return; end
            
            if obj.nSamples == 1 % Special case (i.e no data is loaded)
                newLimits = [0,1]; 
            end
            
            % Set new limits
            set(obj.ax, 'XLim', newLimits);
            
            
            if ~isempty(obj.hScrollbarX) && obj.nSamples ~= 1
                obj.hScrollbarX.VisibleAmount = range(obj.ax.XLim) / (obj.nSamples-1);
                %obj.hScrollbarX.VisibleAmount = range(obj.ax.XLim) / range(extremeLimits);

                % Calculate Value in same way as in the setXLimitsScrollbar
                % function. Nb: Important to prevent recursive calls.
                %
                %   THIS SHIT NEED TO CHANGE!!!
                obj.hScrollbarX.Value = obj.ax.XLim(1) / (round(obj.nSamples-range(obj.ax.XLim)));
                %obj.hScrollbarX.Value = obj.ax.XLim(1) / ( (round(extremeLimits(2)+1-range(obj.ax.XLim)))  );
                
                if abs(obj.hScrollbarX.VisibleAmount - 1) < 0.001
                    obj.hScrollbarX.hide()
                else
                    obj.hScrollbarX.show()
                end
            end
            
            
            drawnow limitrate
            
        end
        
        function setNewYLims(obj, newLimits)
            
            
            yLimExtreme = obj.YLimExtreme.(obj.ActiveYAxis);
            
            if nargin < 2 || isempty(newLimits)
                newLimits = yLimExtreme;
            end
            
            % Todo: Make sure XLim2 > XLim1
            newLimits(1) = max([yLimExtreme(1), newLimits(1)]);
            newLimits(2) = min([yLimExtreme(2), newLimits(2)]);
            
            % Set new limits
            if nargin == 1 || isempty(newLimits)
                set(obj.ax, 'YLim', obj.YLimExtreme.(obj.ActiveYAxis))
                obj.updateFrameMarker('update_y')
%                 set(obj.ax, 'XLim', [1, obj.tsArray(1).Time(end)])
            else
                %newLimits
                set(obj.ax, 'YLim', sort(newLimits));
                obj.updateFrameMarker('update_y')
            end
                                    
            if ~isempty(obj.hScrollbarY)
                
                switch obj.ActiveYAxis
                    case 'left'
                        yLimExtreme = obj.YLimExtreme.left;
                    case 'right'
                        yLimExtreme = obj.YLimExtreme.right;
                end
                
                %obj.hScrollbarY.VisibleAmount = range(obj.ax.YLim) / (obj.nSamples-1);
                obj.hScrollbarY.VisibleAmount = range(obj.ax.YLim) / (range(yLimExtreme)-1);

                % Calculate Value in same way as in the setYLimitsScrollbar
                % function. Nb: Important to prevent recursive calls.
                %
                %   THIS SHIT NEED TO CHANGE!!!
                obj.hScrollbarY.Value = obj.ax.YLim(1) / (round(yLimExtreme(2)+1 - range(obj.ax.YLim)));
                %obj.hScrollbarX.Value = obj.ax.XLim(1) / ( (round(extremeLimits(2)+1-range(obj.ax.XLim)))  );
                
                if abs(obj.hScrollbarY.VisibleAmount - 1) < 0.001
                    obj.hScrollbarY.hide()
                else
                    obj.hScrollbarY.show()
                end
            end
            
        end
        
        function dragYLimits(obj, location)
            
            currentPoint = obj.Figure.CurrentPoint;

            currentYAxisLocation = obj.ax.YAxisLocation;
            switchYAxis = ~strcmp(currentYAxisLocation, location);

            if switchYAxis
                yyaxis(obj.ax, location)
            end

            deltaY = currentPoint(2) - obj.PreviousMousePoint(2);
            deltaY = deltaY / obj.ax.Position(4);
            
            
            yLimRange = range(obj.ax.YLim);
            yLimDiff = yLimRange .* deltaY;

% %             if deltaY < 0
% %                 obj.plotZoom('in', abs(yLimDiff)*10, 'y')
% %             else
% %                 obj.plotZoom('out', abs(yLimDiff)*10, 'y')
% %             end
% %             return
            
            %TODO... Combine with pointertool!
            newYLim = [obj.ax.YLim(1)-yLimDiff, obj.ax.YLim(2)+yLimDiff];
            obj.setNewYLims(newYLim)

% %             if switchYAxis % Switch back...
% %                 yyaxis(obj.ax, currentYAxisLocation)
% %                 currentYAxisLocation
% %             end
                    
        end
        
        function dragXLimits(obj)
            
            currentPoint = obj.Figure.CurrentPoint;
            deltaX = currentPoint(1) - obj.PreviousMousePoint(1);
            deltaX = deltaX / obj.ax.Position(3);

            xLimRange = range(obj.ax.XLim);
            xLimDiff = xLimRange .* deltaX;

            newXLim = [obj.ax.XLim(1)-xLimDiff, obj.ax.XLim(2)+xLimDiff];
            obj.setNewXLims(newXLim)
        end
        
    end
    
    methods (Access = public)
        function synchWithApp(obj, hApp)
            
            obj.SynchedApps(end+1) = hApp;
            
            obj.initializeSynchTimer()
            
        end
    end
    
    methods (Access = protected)
        
        function initializeSynchTimer(obj)
            
            obj.SynchTimer = timer('ExecutionMode', 'fixedRate', ...
               'Period', 0.03);
            obj.SynchTimer.TimerFcn = @obj.checkFrameUpdate;
            
            start( obj.SynchTimer )
        end
        
        function checkFrameUpdate(obj, src, evt)
            
            if ~isvalid(obj); return; end
            
            appFrameNum = obj.SynchedApps(1).currentFrameNo;
            
            if appFrameNum ~= obj.currentFrameNo
                obj.currentFrameNo = appFrameNum;
            end
            
        end

    end
    
    methods (Access = protected)
        
        function position = initializeFigurePosition(obj)
            
            screenSize = get(0, 'ScreenSize');
            
            width = 1;
            height = 0.3;
                        
            figSize = screenSize(3:4) .* [width, height];
            figLoc = screenSize(1:2) - [1,1] + (screenSize(3:4) - figSize)/2;
            figLoc(2) = sum(screenSize([2,4])) - figSize(2) - 45;
            
            %todo: determine offset (45) based on system...
            
            position = [figLoc, figSize];
            
        end
        
        function resizePanel(obj, s, e)
                
            if ~obj.isConstructed; return; end
            
            panelPos = getpixelposition(obj.Panel);
            axesSize = panelPos(3:4) - [sum(obj.Margins([1,3])), sum(obj.Margins([2,4]))];
            axPosition = [obj.Margins(1:2), axesSize];
            
            obj.ax.Position = axPosition;
            obj.InteractionAxes.Position = axPosition;
            
            % Update position of panel with scrollbar
            if isa(obj.hScrollPanelX, 'matlab.ui.container.Panel')
                if isvalid(obj.hScrollPanelX)
                    newPosition = [obj.Margins(1), 5, axesSize(1), 10];
                    obj.hScrollPanelX.Position = newPosition;
                end
            end
            
            if isa(obj.hScrollPanelY, 'matlab.ui.container.Panel')
                if isvalid(obj.hScrollPanelY)
                    xLoc = obj.Figure.Position(3) - 15;
                    newPosition = [xLoc, obj.Margins(2), 10, axesSize(2)];
                    obj.hScrollPanelY.Position = newPosition;
                end
            end
                   
            if ~isempty(obj.signalLegend) && isvalid(obj.signalLegend)
                obj.signalLegend.Position(2) = sum(obj.ax.Position([2,4]))+5;
            end

        end
       
% %         function setDefaultFigureCallbacks(obj, hFig)
% %         
% %             if nargin < 2 || isempty(hFig)
% %                 hFig = obj.Figure;
% %             end
% %             if strcmp(obj.mode, 'docked'); return; end
% %             
% %             % Todo: Need to adapt to standalone vs docked
% %             hFig.WindowScrollWheelFcn = @obj.onMouseScrolled;
% %             hFig.WindowKeyPressFcn = @obj.onKeyPressed;
% %             hFig.WindowKeyReleaseFcn = @obj.onKeyReleased;
% % 
% %         end
        
        function onThemeChanged(obj)
                       
            if ~obj.isConstructed; return; end

            obj.Figure.Color = obj.Theme.FigureBackgroundColor;
            obj.Panel.BackgroundColor = obj.Theme.FigureBackgroundColor;
            obj.Panel.BackgroundColor = obj.Theme.FigureBackgroundColor;
            
            if isa(obj.hScrollPanelX, 'matlab.ui.container.Panel')
                obj.hScrollPanelX.BackgroundColor = obj.Theme.FigureBackgroundColor;
                obj.hScrollPanelY.BackgroundColor = obj.Theme.FigureBackgroundColor;
            end
            
            obj.EventAxes.Color = obj.Theme.AxesBackgroundColor;
            obj.ax.XAxis.Color = obj.Theme.AxesForegroundColor;
            obj.TimeAxis.Color = obj.Theme.AxesForegroundColor;
            for i = 1:numel(obj.ax.YAxis)
                obj.ax.YAxis(i).Color = obj.Theme.AxesForegroundColor;
            end
            obj.ax.GridColor = obj.Theme.AxesForegroundColor;
            obj.ax.GridAlpha = obj.Theme.AxesGridAlpha;
            
        end
    end
    
    methods (Access = {?applify.ModularApp, ?applify.DashBoard} )
        
        function onMouseScrolled(obj, src, event)
        %onMouseScrolled Handle scroll input to gui figure.  
        
        % Use the scrollHistory to avoid "glitchy" scrolling. For small
        % movements on a mousepad, scroll values can come in as 0, 1, 1,
        % -1, 1, 1 even if fingers are moving in on direction.
        
            if ~obj.isMouseInApp; return; end

            obj.scrollHistory = cat(1, obj.scrollHistory(2:5), event.VerticalScrollCount);
            
            switch obj.scrollMode
                
                case 'normal'
                    obj.interactiveFrameChangeRequest(src, event, 'mousescroll')
                    
                case {'zoom_x', 'zoom_y'}
                    
                    switch obj.scrollMode
                        case 'zoom_x'
                            dir = 'x';
                            scrollFactor = abs(event.VerticalScrollCount ) .* obj.settings.ScrollFactorZoomX;
                        case 'zoom_y'
                            dir = 'y';
                            scrollFactor = abs(event.VerticalScrollCount ) .* obj.settings.ScrollFactorZoomY;
                    end
%                     scrollFactor
%                     fprintf('%d    - ', event.VerticalScrollCount)

                    if event.VerticalScrollCount > 0 && sum(obj.scrollHistory) > 0 
                        obj.plotZoom('in', scrollFactor, dir);
                    elseif event.VerticalScrollCount < 0  && sum(obj.scrollHistory) < 0
                         obj.plotZoom('out', scrollFactor, dir );
                    end
                    
                case 'zoom_both'
                    
                    
            end
            
        end
        
        function onKeyPressed(obj, ~, event)

            if ~obj.isMouseInApp; return; end
               
            if ~isempty(obj.PointerManager)
                wasCaptured = obj.PointerManager.onKeyPress([], event);
                if wasCaptured; return; end
            end
            
            switch event.Key
                case 'shift'
                    obj.scrollMode = 'zoom_x';
                
                case 'leftarrow'
                    if contains(event.Modifier, 'shift')
                        xRange = range(obj.ax.XLim);
                        goto = obj.currentFrameNo - xRange;
                        if goto < 1; goto = 1; end
                        obj.interactiveFrameChangeRequest(struct('String', goto), [], 'jumptoframe')
%                         setNewXLims(obj, obj.ax.XLim - xRange)
                    else
                        obj.interactiveFrameChangeRequest([], [], 'prev')
                    end
                case 'rightarrow'
                    if contains(event.Modifier, 'shift')
                        xRange = range(obj.ax.XLim);
                        goto = obj.currentFrameNo + xRange;
                        obj.interactiveFrameChangeRequest(struct('String', goto), [], 'jumptoframe')
%                         setNewXLims(obj, obj.ax.XLim + xRange)
                    else
                        obj.interactiveFrameChangeRequest([], [], 'next')
                    end
                    
                case {'x', 'X'}
                    if event.Character == 'x'
                        obj.plotZoom('in');
                    else
                        obj.plotZoom('out');
                    end
                case {'y', 'Y'}
                    obj.scrollMode = 'zoom_y';
                    if event.Character == 'y'
                        obj.plotZoom('in', obj.settings.ScrollFactorZoomY, 'y');
                    else
                        obj.plotZoom('out', obj.settings.ScrollFactorZoomY, 'y');
                    end
                    
                    
                    
                case 'r'
                    obj.setNewXLims;
                    obj.setNewYLims;

                    
            end
        end
        
        function onKeyReleased(obj, ~, event)
            
            switch event.Key
               case 'shift'
                    obj.scrollMode = 'normal'; 
               case 'y'
                    obj.scrollMode = 'normal'; 
            end
            
        end
        
        function onMousePressed(obj, src, event)
        %onMousePressed Callback for mouse press in figure.
        
            if strcmp(obj.Figure.SelectionType, 'normal')
                                
                obj.isMouseDown = true;
                obj.PreviousMouseClickPoint = obj.Figure.CurrentPoint;
                obj.PreviousMousePoint = obj.Figure.CurrentPoint;

                if ~isempty( obj.PointerManager )
                    if ~isempty( obj.PointerManager.currentPointerTool )
                        return
                    end
                end

                obj.interactiveFrameChangeRequest(src, event, 'mousepress')
            
                
            elseif strcmp(obj.Figure.SelectionType, 'open')
                xPoint = round( obj.ax.CurrentPoint(1) );
                ind = obj.isPointInEventVector( xPoint );

                if ~isempty(ind) && ~isempty(obj.PointerManager)
                    if ~isa(obj.PointerManager.currentPointerTool, 'signalviewer.pointerTool.eventAnnotator')
                        obj.PointerManager.togglePointerMode('eventAnnotator')
                    end
                    
                    if obj.PointerManager.currentPointerTool.isActive
                        obj.PointerManager.currentPointerTool.deactivate()
                    end
                    
                    S = obj.gatherEventData(ind, xPoint);
                    obj.PointerManager.currentPointerTool.startEdit(S)
                    
                else
                    if ~isempty(obj.PointerManager)
                        if isa(obj.PointerManager.currentPointerTool, 'signalviewer.pointerTool.eventAnnotator')
                            obj.PointerManager.togglePointerMode('eventAnnotator')
                        end
                    end
                end
            end
                        
        end
        
        function onMouseMotion(obj, ~, event)
          
            isOnAxis = obj.isPointOnAxis();

            if strcmp(isOnAxis, 'y')
                obj.Figure.Pointer = 'top';
            elseif strcmp(isOnAxis, 'x')
                obj.Figure.Pointer = 'left';
            else
                if ~isempty(obj.PointerManager) % Temporary. In case subclass has not assigned pointermanager
                    if isempty(obj.PointerManager.currentPointerTool)
                        obj.Figure.Pointer = 'arrow';
                    end
                else
                    obj.Figure.Pointer = 'arrow';
                end
            end
            
            if obj.isMouseDown
                [isOnAxis, location] = obj.isPointOnAxis(obj.PreviousMouseClickPoint);

                currentPoint = obj.Figure.CurrentPoint;

                if strcmp(isOnAxis, 'y')
                    obj.dragYLimits(location)
                elseif strcmp(isOnAxis, 'x')
                    obj.dragXLimits()
                end
                
                obj.PreviousMousePoint = currentPoint;
            end
            
        end
        
        function onMouseReleased(obj, src, event)
            obj.isMouseDown = false;
            obj.PreviousMouseClickPoint = [];
        end
    end
    
    methods (Static)
        
        function pathStr = getIconPath()
            % Set system dependent absolute path for icons.

            rootDir = utility.path.getAncestorDir(mfilename('fullpath'), 0);
            pathStr = fullfile(rootDir, 'resources', 'icons');

        end
        
        function hApp = uiSelectViewer(viewerNames, hFigure)
        
            % Todo: make this method of superclass??
            % INPUTS:
            %   viewerNames : list (cell array) of app names to look for
            %   hFigure : figure handle of figure to ignore (optional)
            %   
            %   
            % Supported names: {'StackViewer', 'Signal Viewer', 'Roi Classifier'}

            if nargin < 1
                viewerNames = {'Signal Viewer'};
            end
            if nargin < 2
                hFigure = [];
            end
            
            hApp = [];
            
            % Find all open figures that has a viewer object.
            openFigures = findall(0, 'Type', 'Figure');

            isMatch = contains({openFigures.Name}, viewerNames);

            % Dont include self.
            isMatch = isMatch & ~ismember(openFigures, hFigure)';

            if any(isMatch)
                tf = true;
            else
                tf = false;
            end
            
            if ~tf
                return
            end

            figInd = find(isMatch);

            % Select figure window from selection dialog
            if sum(isMatch) > 1

                figNames = {openFigures(figInd).Name};
    %             figNumbers = [openFigures(figInd).Number];
    %             figNumbers = arrayfun(@(n) sprintf('%d:', n), figNumbers, 'uni', 0); 
    %             figNames = strcat(figNumbers ,figNames);

                % Open a listbox selection to figure
                [selectedInd, tf] = listdlg(...
                    'PromptString', 'Select figure:', ...
                    'SelectionMode', 'single', ...
                    'ListString', figNames );

                if ~tf; return; end

                figInd = figInd(selectedInd);

            end

            hApp = getappdata(openFigures(figInd), 'ViewerObject');

        end

    end

end