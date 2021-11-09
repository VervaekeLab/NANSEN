classdef UIComponentCanvas < handle & uim.mixin.assignProperties % uix.Container &  uiw.mixin.AssignPVPairs
%UIComponentCanvas A class based canvas for drawing modern ui components
%
%   Description
%       Built around an axes which overlays all other components in a
%       figure. All interactivity of the axes is turned off, but components
%       can be plotted in the axes. This provides a high level of style
%       customization, because the appearance of a component is only
%       limited by what its possible to plot.
%

% Note: In general, it is better to parent the canvas in a panel than
% directly in a figure. When resizing the figure window, if the canvas axes
% is parented to a figure, things appear more glitchy (the axes is 
% temporarily squeezed when figure size is decreased) than if the axes is 
% parented to a panel.

% Note: 
% The 'DefaultAxesCreateFcn' property of figure is used to notify whenever 
% a new axes is created on the figure. This is done to make sure the
% UIComponentCanvas axes is always on top.
%
% This canvas will obviously not work in a figure/uifigure which has
% multiple panels, since panels stack on top of axes.

% QUESTIONS:
% What would be the benefit of subclassing from uix.Container? I get some
% properties and functionality which makes this class parts of the graphics
% object family, but I also inherit stuff I dont fully understand. I.e,
% what does an extra container in the figure do? Where is it in the stack?


% Todo: 
%   [ ] Create a variation of UIComponentCanvas for single components.
%   [ ] Outsource tooltip manager to a separate class.
%   [ ] Debug object desctruction...

    
    properties (SetAccess = private, Transient)
        Parent = []                 % Parent handle (figure/uifigure)
        Axes = []                   % Handle to the axes which components are plotted in
        Position (1,4) double = [0,0,1,1] % Position within the parent. 
        Units = 'pixels'            % Units for position property
        Children = []               % List of uicomponents
        Tag = 'UI Component Canvas' % A tag which is also applied to the axes.
    end
    
    properties (Dependent, Transient)
        Size
    end
    
    properties (Access = private, Transient, Hidden)
        PreviousPixelPosition = [nan, nan, nan, nan]
        PixelPosition = [nan, nan, nan, nan]
        PixelSize = [nan, nan]
        ParentSizeChangedListener event.listener = event.listener.empty
        ParentLocationChangedListener event.listener = event.listener.empty
        TooltipHandle
        ParentDestroyedListener
    end
    
    events
        SizeChanged
    end
    
    methods % Structors
        function obj = UIComponentCanvas(hParent, varargin)
            
            if nargin < 1; hParent = figure; end
            
            obj.Parent = hParent;

            obj.parseInputs(varargin{:})
            %obj.assignPVPairs(varargin{:})
            
            obj.onSizeChanged() % Call update because we set the parent
            
            obj.createAxes()
            obj.createTooltipHandle()
            
            obj.configureParentPositionChangedListener()
            obj.configureSiblingCreatedListener()
            
            el = addlistener(obj.Parent, 'ObjectBeingDestroyed', @(src,evt) delete(obj));
            obj.ParentDestroyedListener = el;
            
            if ~nargout
                clear obj
            end
            
        end
        
        function delete(obj)
            delete(obj.Axes)
            delete(obj.ParentSizeChangedListener)
            delete(obj.ParentLocationChangedListener)
        end
        
    end
    
    methods
        
        function showTooltip(obj, text, position)
            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)
                
                obj.TooltipHandle.String = text;
                obj.TooltipHandle.Visible = 'on';
                
                extent = obj.TooltipHandle.Extent;
                lim = {'XLim', 'YLim'};
                for i = 1:2
                    if position(i) - extent(i+2) < obj.Axes.(lim{i})(1)
                        position(i) = obj.Axes.(lim{i})(1) +  extent(i+2) + 3; % + obj.TooltipHandle.Margin*2;
                    elseif position(i) + extent(i+2) > obj.Axes.(lim{i})(2)
                        position(i) = obj.Axes.(lim{i})(2) - extent(i+2)*1.1;% - obj.TooltipHandle.Margin*2;
                    end
                end
                
                obj.TooltipHandle.Position(1:2) = position;
                % drawnow limitrate
            end
        end
        
        function hideTooltip(obj)
            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)
                obj.TooltipHandle.String = '';
                obj.TooltipHandle.Visible = 'off';
            end
        end
        
        function arrangeTooltipHandle(obj)
            uistack(obj.TooltipHandle, 'top')
        end
        
        function bringTooltipToFront(obj)
            uistack(obj.TooltipHandle, 'top')
        end
        
    end
    
    methods (Access = private) % Creation
        
        function createAxes(obj)
        %createAxes Create the axes of the UIComponentCanvas
        
        % Important. HitTest and Pickable parts need to be on and visible
        % for children of the axes to be able to capture mouseclicks.!
        
            matlabVersion = version('-release');
            doDisableToolbar = str2double(matlabVersion(1:4))>2018 || ...
                                       strcmp(matlabVersion, '2018b');

            if doDisableToolbar
                args = {'Toolbar', []};
            else
                args = {};
            end
        
            obj.Axes = axes(obj.Parent, args{:});
            
            obj.Axes.Position = obj.Position;
            obj.Axes.Units = obj.Units;
            obj.Axes.Visible = 'off';
            obj.Axes.HandleVisibility = 'off';
            obj.Axes.HitTest = 'on';
            obj.Axes.PickableParts = 'visible';
            obj.Axes.Tag = 'UI Component Canvas Axes';
            obj.Axes.ButtonDownFcn = @(s,e,str) disp('c');

            obj.Axes.Color = [0.2,0.2,0.2];

            hold(obj.Axes, 'on')
            
% %             obj.Axes.DataAspectRatio = [1 1 1];
% %             obj.Axes.DataAspectRatioMode = 'manual';
% %             axis(obj.Axes, 'equal')

            obj.setAxesLimits()
            
            if doDisableToolbar
                disableDefaultInteractivity(obj.Axes)
            end
            
        end

        function configureParentPositionChangedListener(obj)
            
            % Delete listeners if they already exist.
            if ~isempty(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
            end
            
            if ~isempty(obj.ParentLocationChangedListener)
                delete(obj.ParentLocationChangedListener)
            end
            
            
            % Create listeners for Parent's SizeChanged & LocationChanged
            el = listener(obj.Parent, 'SizeChanged', @obj.onSizeChanged);
            obj.ParentSizeChangedListener = el;

            el = listener(obj.Parent, 'LocationChanged', @obj.onLocationChanged);
            obj.ParentLocationChangedListener = el;

            % todo: check matlab version
%             if matlab.ui.internal.isUIFigure(obj.Parent)
%                 obj.Parent.AutoResizeChildren = 'off';
%                 obj.Parent.SizeChangedFcn = @obj.onSizeChanged;
%             end
        end
        
        function configureSiblingCreatedListener(obj)
        %configureSiblingCreatedListener Need to know when a sibling is born
            
            % Use the undocumented DefaultAxesCreationFcn property of
            % figure to run a callback whenever new axes are added to the
            % figure. This is done because our axes always need to stay on
            % top of the uistack.
            
            % Note, this is more like a dummy listener...
            
            set(obj.Parent, 'DefaultAxesCreateFcn', @obj.onSiblingCreated)
            
        end
        
        function createTooltipHandle(obj) %todo: Make class...
            
            hAx = obj.Axes;
            
            % Create a tooltip...
            obj.TooltipHandle = text(hAx, 1,1, '');
            obj.TooltipHandle.BackgroundColor = ones(1,3) * 0.2;
            obj.TooltipHandle.Color = ones(1,3) * 0.8;
            obj.TooltipHandle.EdgeColor = 'none';
            obj.TooltipHandle.FontName = 'Avenir Next';
            obj.TooltipHandle.FontSize = 12;
            obj.TooltipHandle.HorizontalAlignment = 'left';
            obj.TooltipHandle.VerticalAlignment = 'top';
            obj.TooltipHandle.Visible = 'off';
            obj.TooltipHandle.HitTest = 'off';
            obj.TooltipHandle.PickableParts = 'none';
            
        end
        
    end
    
    methods (Access = protected) % Event callbacks
        
        function onSizeChanged(obj, ~, evt)
        %onSizeChanged Call an update to the PixelSize property
            newParentPosition = getpixelposition(obj.Parent);
            
            persistent t0
            if isempty(t0); t0 = clock; t0 = t0(6); end
            
            oldSize = obj.PixelSize;
            newSize = newParentPosition(3:4);
                        
            obj.PreviousPixelPosition = obj.PixelPosition;
            obj.PixelPosition = newParentPosition;
            
            obj.PixelSize = newSize;
            
            if nargin < 2 || isempty(evt) % On creation...
                evt = event.EventData;
            else
                evt = uim.event.SizeChangedData(oldSize, newSize);
            end
            

            obj.notify('SizeChanged', evt)

        end
        
        function onLocationChanged(obj, ~, evt)
            
            obj.PreviousPixelPosition = obj.PixelPosition;
            obj.PixelPosition = getpixelposition(obj.Parent);

        end
        
        function onSiblingCreated(obj, ~, ~)
        %onSiblingCreated Keep our axes on top of the uistack
            try
                uistack(obj.Axes, 'top')
            catch ME
                switch ME.identifier
                    case 'MATLAB:ui:uifigure:UnsupportedAppDesignerFunctionality'
                        obj.Axes.HandleVisibility = 'on';
                        IND = 1:numel(obj.Parent.Children);
                        IND(end-1:end) = IND([end,end-1]);
                        obj.Parent.Children = obj.Parent.Children(IND);
                        obj.Axes.HandleVisibility = 'off';
                end
            end
        end
        
    end
    
    methods (Access = private) % Internal updates
        
        function setAxesLimits(obj)
        %setAxesLimits Set limits of the UIComponentCanvas axes.
        
            % Abort if axes is not created yet.
            if isempty(obj.Axes); return; end
                
            if strcmp(obj.Axes.Units, 'pixels')

% %                 if ~all(isnan(obj.PreviousPixelPosition))
% %                     obj.setAxesLimitsRelative()                
% %                 else
                    newPosition = [1,1, obj.PixelSize];

                    set(obj.Axes, 'Position', newPosition, 'XLim', [1, obj.PixelSize(1)], 'YLim', [1, obj.PixelSize(2)])
% %                     
% %                 end

            else
                obj.Axes.XLim = [1, obj.PixelSize(1)];
                obj.Axes.YLim = [1, obj.PixelSize(2)];
            end
                    
        end
        
        function setAxesLimitsRelative(obj)
        %setAxesLimitsRelative Adjust axes limits relative to current view
        %
        %   Alternative to always updating limits while keeping lower left
        %   corner as a fixed point (1,1)
        
        %   NB: Currently not in use
        
            % Calculate position changes
            deltaX = obj.PixelPosition(1) - obj.PreviousPixelPosition(1);
            deltaY = obj.PixelPosition(2) - obj.PreviousPixelPosition(2);
            deltaW = obj.PixelPosition(3) - obj.PreviousPixelPosition(3);
            deltaH = obj.PixelPosition(4) - obj.PreviousPixelPosition(4);
                    
                    
            if deltaX ~= 0 && deltaW ~= 0
                newXLim(1) = obj.Axes.XLim(1) + deltaX;
                newXLim(2) = newXLim(1) + obj.PixelSize(1);
            elseif deltaX == 0 && deltaW ~= 0
                newXLim(2) = obj.Axes.XLim(2);
                newXLim(1) = obj.Axes.XLim(2) - obj.PixelSize(1);
            else
                newXLim = obj.Axes.XLim;
            end

            if deltaY ~= 0 && deltaH ~= 0
                newYLim(1) = obj.Axes.YLim(1) + deltaY;
                newYLim(2) = newYLim(1) + obj.PixelSize(2);
            elseif deltaY == 0 && deltaH ~= 0
                newYLim(2) = obj.Axes.YLim(2);
                newYLim(1) = obj.Axes.YLim(2) - obj.PixelSize(2);
            else
                newYLim = obj.Axes.YLim;
            end
                                    
            % Update axes position and limits.
            newPosition = [obj.Axes.Position(1:2), obj.PixelSize];
            set(obj.Axes, 'Position', newPosition, 'XLim', newXLim, 'YLim', newYLim)
            
        end
        
        function removeParent(obj)
            
            set(obj.Parent, 'DefaultAxesCreateFcn', [])

            if ~isempty(obj.ParentDestroyedListener)
                delete(obj.ParentDestroyedListener)
                obj.ParentDestroyedListener = [];
            end
            
            if ~isempty(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
                obj.ParentSizeChangedListener = [];
            end
            
            if ~isempty(obj.ParentLocationChangedListener)
                delete(obj.ParentLocationChangedListener)
                obj.ParentLocationChangedListener = [];
            end
            
        end
        
        function reparentAxes(obj)
            obj.Axes.Parent = obj.Parent;
            
            obj.onSizeChanged()
            obj.setAxesLimits()
            
            obj.configureParentPositionChangedListener()
            obj.configureSiblingCreatedListener()
        end
    end
    
    methods % Set/Get
        
        function size = get.Size(obj)
            size = obj.PixelSize;
        end
        
        function set.Parent(obj, newValue)
        %set.Parent Validate value and assign to Parent property   
        
            errMsg = sprintf(['Error setting property ''Parent'' of class ''%s'': \n', ...
                    'Value must be ''matlab.graphics.Graphics'''], class(obj));
                
            assert( isa(newValue, 'matlab.graphics.Graphics'), errMsg)
            
            hadParent = ~isempty(obj.Parent) && isvalid(obj.Parent);
            
            if hadParent
                obj.removeParent(obj); 
            end
            
            obj.Parent = newValue;
            
            % Add class instance to appdata of the parent handle
            setappdata(obj.Parent, 'UIComponentCanvas', obj);
            
            if hadParent
                obj.reparentAxes(); 
            end
            
        end
        
        function set.PixelSize(obj, newValue)
            
            assert(isnumeric(newValue) && numel(newValue)==2, ...
                'uim:InvalidPropertyValue', ...
                'PixelSize should be a vector of two elements')
            
            isPixelSizeChanged = any(newValue ~= obj.PixelSize);
            if ~isPixelSizeChanged; return; end
            
            obj.PixelSize = newValue;
            
            % Update axes limits to correspond with the canvas pixelsize.
            obj.setAxesLimits()
            
        end
        
        function locationPoint = getLocationPoint(obj, locationKey)
            
            pixelSize = obj.PixelSize;
            
            locationPoint = [1,1]; % Southwest
            %locationPoint = [obj.Axes.XLim(1), obj.Axes.YLim(1)]; % Southwest
            
            
            if contains(locationKey, 'north')
                locationPoint(2) = pixelSize(2);
            end
            
            if contains(locationKey, 'east')
                locationPoint(1) = pixelSize(1);

            end
            
            % Center along x-dimension
            if strcmp(locationKey, 'south') || strcmp(locationKey, 'north')
                locationPoint(1) = pixelSize(1)/2;
            end
            
            % Center along y-dimension
            if strcmp(locationKey, 'west') || strcmp(locationKey, 'east')
                locationPoint(2) = pixelSize(2)/2;
            end
            
            if strcmp(locationKey, 'center')
                locationPoint = pixelSize/2;
            end
            
            locationPoint = round( locationPoint );

        end
        
    end
    
    methods (Static)
        
        function hAxes = createComponentAxes(hParent, n)
            
            if nargin < 2
                n = 1;% Number of axes to create (Todo)
            end
            
            matlabVersion = version('-release');
            doDisableToolbar = str2double(matlabVersion(1:4))>2018 || ...
                                       strcmp(matlabVersion, '2018b');

            if doDisableToolbar
                args = {'Toolbar', []};
            else
                args = {};
            end
            
            hAxes = axes(hParent, args{:});

            set(hAxes, 'XTick', [], 'YTick', [])
            hAxes.Visible = 'off';
            hAxes.Units = 'pixel';         
            hAxes.HandleVisibility = 'off';
            hAxes.Tag = 'Widget Container';
            
            axis(hAxes, 'equal')
            hold(hAxes, 'on')
            
            if doDisableToolbar
                disableDefaultInteractivity(hAxes)
            end
            
        end
        
    end
    
end



% % Test SizeChangedListener
% % f=figure;
% % uicc = uim.UIComponentCanvas(f);
% % el = listener(uicc, 'SizeChanged', @(s,e) disp(e));