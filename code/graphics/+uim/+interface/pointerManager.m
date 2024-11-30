classdef pointerManager < handle
%pointerManager.m A manager for switching between different interactive
% pointer tools in axes.
%
%   See also uim.interface.abstractPointer


% List of things to implement
%   Keypress sequences should be read from settings somehow
%   Also: Migrate other things from a settings file/preferences...
%   Need to capture the figure's scroll callback.
%   [x] use listeners instead of attaching mouse function to figure handle



    properties
        
        hFigure % Axes or figure
        hAxes
        
        pointers 
        
        supportedTools
        
        defaultPointerTool
        
        currentPointerTool
        previousPointerTool
        
        wasCursorInAxes = false;
    end
    
    properties (SetAccess = private)
        OriginalAxesButtonDownFcn = [] % Store axes function
    end
    
    properties (Access = private)
        AxesButtonPressListener event.listener
        WindowButtonMotionListener event.listener
        WindowButtonUpListener event.listener
        WindowScrollWheelListener event.listener % todo
        %WindowKeyPressListener event.listener
    end
        
    properties (Access = protected)
        isMouseButtonDown (1,1) logical = false
        PreviousMousePoint (1,2) double = [nan, nan]
        PreviousMouseClickPoint   % Point where mouse was last clicked
    end
    
    
    methods % Structors

        function obj = pointerManager(hFigure, hAxes, pointerNames)
        %pointerManager Attach a pointerManager to a figure
            
            obj.hFigure = hFigure;
            obj.hAxes = hAxes;
            
            % Assign dummy callback if WindowButtonMotionFcn is unassigned
            if isempty( hFigure.WindowButtonMotionFcn )
                hFigure.WindowButtonMotionFcn = @obj.mouseMotionDummyCallback;
            end

            % Create listeners for mouse event in figure
            obj.createFigureMouseListeners()
            
            % Store current axes button down function
            if ~isempty(hAxes.ButtonDownFcn)
                obj.OriginalAxesButtonDownFcn = hAxes.ButtonDownFcn;
            end
            
            % Assign pointerManager callbacks to figure
            hAxes.ButtonDownFcn = @obj.onButtonDown; % Use button down callback of axes..
            hAxes.Interruptible = 'off'; % Todo: are there cases where its better if this is on?
            
            hold(obj.hAxes, 'on')
            
            if nargin >= 3 &&  ~isempty(pointerNames)
                obj.initializePointers(hAxes, pointerNames)
            end
            
            if ~nargout
                clear obj
            end
            
        end
        
        function delete(obj)
        %delete Delete method for pointermanager.
        
            obj.deleteFigureMouseListeners()
            
            if isvalid(obj.hAxes)
                if isequal( obj.hAxes.ButtonDownFcn, @obj.onButtonDown)
                    obj.hAxes.ButtonDownFcn = [];
                end
                
                if ~isempty(obj.OriginalAxesButtonDownFcn)
                    obj.hAxes.ButtonDownFcn = obj.OriginalAxesButtonDownFcn;
                end
            end
        end
        
    end
    
    methods (Access = private)
        
        function createFigureMouseListeners(obj)
        
            %obj.WindowMousePressListener = addlistener(obj.hFigure, ...
            %    'WindowMousePress', @obj.onMousePressed);

            obj.WindowButtonMotionListener = addlistener(obj.hFigure, ...
                 'WindowMouseMotion', @obj.onButtonMotion);

            obj.WindowButtonUpListener = addlistener(obj.hFigure, ...
                'WindowMouseRelease', @obj.onButtonRelease);

            %obj.WindowScrollWheelListener = addlistener(obj.hFigure, ...
            %    'WindowScrollWheel', @obj.onMouseScrolled);

            % Should this be independent, or called from external gui?
            %obj.WindowKeyPressListener = addlistener(obj.hFigure, ...
            %    'WindowKeyPress', @obj.onKeyPress);
        end
        
        function deleteFigureMouseListeners(obj)
           
            isdeletable = @(x) ~isempty(x) && isvalid(x);
            
            if isdeletable(obj.WindowButtonMotionListener)
                delete(obj.WindowButtonMotionListener)
            end
            
            if isdeletable(obj.WindowButtonUpListener)
                delete(obj.WindowButtonUpListener)
            end
            
%             if isdeletable(obj.WindowKeyPressListener)
%                 delete(obj.WindowKeyPressListener)
%             end
            
        end
    end
    
    methods
        
        function onFigureChanged(obj)
            
            
        end
        
        function initializePointers(obj, hAxes, pointerRef)
            
            if ~isa(pointerRef, 'cell'); pointerRef = {pointerRef}; end
            
            for i = 1:numel(pointerRef)
                
                if isa(pointerRef{i}, 'char')
                    thisPointerName = pointerRef{i};
                    thisPointerRef = str2func(sprintf(...
                        'uim.interface.pointerTool.%s', thisPointerName));
                else
                    thisPointerRef = pointerRef{i};
                    thisPointerName = strsplit(func2str(thisPointerRef), '.');
                    thisPointerName = thisPointerName{end};
                end
                obj.pointers.(thisPointerName) = thisPointerRef(hAxes);
            end
            
        end
        
        function updatePointerSymbol(obj)
            if ~isempty(obj.currentPointerTool)
                obj.currentPointerTool.setPointerSymbol()
            end
        end
        
        function onButtonDown(obj, src, event)
            
            % Todo: rename onButtonDownInAxes
                        
            % 1) Call default axes button down callback
%             if ~isempty(obj.OriginalAxesButtonDownFcn)
%                 obj.OriginalAxesButtonDownFcn(src, event)
%             end
            
            % 2) Call active pointer tool
            if obj.isCursorInsideAxes(obj.hAxes)
                if ~isempty(obj.currentPointerTool)
                    obj.currentPointerTool.onButtonDown(src, event)
                end
            end

        end
        
        function onButtonMotion(obj, src, event)
            
            if isempty(obj.currentPointerTool); return; end
            tf = obj.isCursorInsideAxes(obj.hAxes);

            % Change cursor symbol when pointer enters or leaves axes
            if tf && ~obj.wasCursorInAxes % Entered axes
                if ~isempty(obj.currentPointerTool)
                    obj.currentPointerTool.setPointerSymbol()
                end
                obj.currentPointerTool.onPointerEnteredAxes()
            elseif ~tf && obj.wasCursorInAxes % Left axes
                set(obj.hFigure, 'Pointer', 'arrow');
                obj.currentPointerTool.onPointerExitedAxes()
            end
            
            
            % Create extended eventdata containing mousepoint coordinates?
            
            % 2) Call active pointer tool
            if ~isempty(obj.currentPointerTool)% && ~isSuspended(obj.currentPointerTool) Some tools, like zoom, should continue to workeven when cursor moves outside axes...
                obj.currentPointerTool.onButtonMotion(src, event)
            end
            

            if tf
                obj.wasCursorInAxes = true;
            else
                obj.wasCursorInAxes = false;
            end
            
            %drawnow limitrate
            
        end
        
        function onButtonRelease(obj, src, event)
            
            % Redirect to callback of active pointer tool
            if ~isempty(obj.currentPointerTool)
                obj.currentPointerTool.onButtonUp(src, event)
            end
        end
        
        function keyPressCallbackFunction(varargin)
            wasCaptured = obj.onKeyPress(src, event);
            clear wasCaptured
        end
        
        function wasCaptured = onKeyPress(obj, src, event)
            
            % Todo: Make a system for having unique key shortcuts and
            % setting/changing them from one location..
            
            % if ~obj.isCursorInsideAxes(obj.hAxes); return; end
            % disp(event.Key)

            wasCaptured = true;
            if isempty(event.Modifier)
                switch event.Key
                    case 'x'
                        obj.togglePointerMode('crop')
                    case 'q'
                        obj.togglePointerMode('zoomIn')
                    case 'w'
                        obj.togglePointerMode('zoomOut')
                    case 'y'
                        obj.togglePointerMode('pan')
                    case 'i'
                        obj.togglePointerMode('dataCursor')
                    case 's'
                        obj.togglePointerMode('selectObject')
                    case 'd'
                        obj.togglePointerMode('polyDraw')
                    case 'o'
                        obj.togglePointerMode('circleSelect')
                    case 'a'
                        obj.togglePointerMode('autoDetect')
                    case 't'
                        obj.togglePointerMode('freehandDraw')

                    otherwise
                        wasCaptured = false;
                end
            else
                wasCaptured = false;
            end
            
            % 2) Call pointertool's keypress
            if ~isempty(obj.currentPointerTool)
                wasCaptured = obj.currentPointerTool.onKeyPress(src, event) || wasCaptured;
            end
            
            if ~nargout
                clear wasCaptured
            end
        end

        function wasCaptured = onKeyRelease(obj, src, event)
            persistent notifyUser
            if isempty(notifyUser)
                notifyUser = false;
                if ispc; notifyUser = true; end 
            end
            
            if strcmp(event.Key, 'alt')
                if notifyUser
                    nansen.common.uiinform.roimanager.notifyUserAboutStrangeAltBehaviorOnWindows()
                    notifyUser = false;
                end
            end
            wasCaptured = false;
            if ~isempty(obj.currentPointerTool)
                wasCaptured = obj.currentPointerTool.onKeyRelease(src, event);
            end
        end
        
        function togglePointerMode(obj, pointerName)
            % button press from toolbar or keypress callback.     
            
            % If the pointerName refers to the current pointer tool, it
            % should be turned off.
            if ~isfield(obj.pointers, pointerName); return; end
            
            toggleOff = isequal(obj.currentPointerTool, obj.pointers.(pointerName));
            
            switch obj.pointers.(pointerName).exitMode
                
                case 'default'
                    
                    if ~isempty(obj.currentPointerTool)
                        obj.currentPointerTool.deactivate();
                        obj.previousPointerTool = []; %Make sure this is reset.
                    end
                    
                    if toggleOff  % Turn off tool which has exitmode default
                        
                        % Change to default tool
                        obj.currentPointerTool = obj.defaultPointerTool;
                        
                    else  % Turn on tool which has exitmode default
                        
                        % If previous tool is populated, turn off and flush
                        if ~isempty(obj.previousPointerTool)
                            obj.previousPointerTool.deactivate();
                            obj.previousPointerTool = [];
                        end
                        obj.currentPointerTool = obj.pointers.(pointerName);
                        
                    end
                
                case 'previous'
                    
                    if toggleOff  % Turn off tool which has exitmode previous
                        
                        % Set current to previous if available
                        obj.currentPointerTool.deactivate();
                        if ~isempty(obj.previousPointerTool)
                            obj.currentPointerTool = obj.previousPointerTool;
                        else
                            obj.currentPointerTool = [];
                        end
                        
                    else  % Turn on tool which has exitmode previous
                        if ~isempty(obj.currentPointerTool)
                            if strcmp(obj.currentPointerTool.exitMode, 'default')
                                obj.currentPointerTool.suspend()
                                obj.previousPointerTool = obj.currentPointerTool;
                            else
                                % If exitMode is previous, we dont want to
                                % store it in the "previous" property.
                                obj.currentPointerTool.deactivate()
                            end
                        end
                        
                        obj.currentPointerTool = obj.pointers.(pointerName);
                        
                    end
                  
            end
            
            if ~isempty(obj.currentPointerTool)
                obj.currentPointerTool.activate();
            else
                obj.hFigure.Pointer = 'arrow';
            end
            
        end
        
        function tf = isCursorInsideAxes(obj, hAx)
            
            currentPoint = hAx.CurrentPoint(1, 1:2);
            
            xLim = hAx.XLim;
            yLim = hAx.YLim;
            
            axLim = [xLim(1), yLim(1), xLim(2), yLim(2)];

            % Check if mousepoint is within axes limits.
            tf = ~any(any(diff([axLim(1:2); currentPoint; axLim(3:4)]) < 0));
            
        end
        
        function tf = pointerEnteredAxes(obj)

            
        end
        
        function tf = pointerExitedAxes(obj)
        
        end
        
    end

    methods (Access = private)
        
        function mouseMotionDummyCallback(obj, src, evt)
            % Assign this if the WindowButtonMotionFcn of a figure is empty
            
            % The figure's CurrentPoint property is only updated if a
            % mousemotion callback is assigned.
            
        end
    end
end