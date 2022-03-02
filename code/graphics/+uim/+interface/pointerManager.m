classdef pointerManager < handle
%pointerManager.m A manager for switching between different interactive
% pointer tools
%
%   See also uim.interface.abstractPointer



% List of things to implement
%   Keypress sequences should be read from settings somehow
%   Also: Migrate other things from a settings file/preferences...
%   Need to capture the figure's scroll callback.
%   [ ] use listeners instead of attaching mouse function to figur handle



    properties
        
        hFigure % Axes or figure
        hAxes
        
        pointers 
        
        supportedTools
        
        defaultPointerTool
        
        currentPointerTool
        previousPointerTool
        
        wasCursorInAxes = false;
        
        
        defaultFigureCallbacks;
    end
        
    properties (Access = protected)
        isMouseButtonDown (1,1) logical = false
        PreviousMousePoint (1,2) double = [nan, nan]
        PreviousMouseClickPoint   % Point where mouse was last clicked
    end
    
    
    methods
        

        function obj = pointerManager(hFigure, hAxes, pointerNames)
            % Attach a pointerManager to a figure
            
            % Store default callbacks in a struct
            obj.defaultFigureCallbacks = struct( ...
                'ButtonDownFcn', {hAxes.ButtonDownFcn}, ...
                'WindowButtonMotionFcn', {hFigure.WindowButtonMotionFcn}, ...
                'WindowButtonUpFcn', {hFigure.WindowButtonUpFcn});% , ...
                %'KeyPressFcn', {hFigure.KeyPressFcn} );
            
            % Assign pointerManager callbacks to figure
            hAxes.ButtonDownFcn = @obj.onButtonDown; % Use button down callback of axes..
            hFigure.WindowButtonMotionFcn = @obj.onButtonMotion;
            hFigure.WindowButtonUpFcn = @obj.onButtonRelease;
            %hFigure.KeyPressFcn = @obj.onKeyPress;
                 
            obj.hFigure = hFigure;
            obj.hAxes = hAxes;
            hold(obj.hAxes, 'on')
            
            if nargin >= 3 &&  ~isempty(pointerNames)
                obj.initializePointers(hAxes, pointerNames)
            end
            
            
            if ~nargout
                clear obj
            end
            
        end
        
        function delete(obj)
             
            % Restore figure/axes callbacks
            if isvalid(obj.hAxes)
                obj.hAxes.ButtonDownFcn = obj.defaultFigureCallbacks.ButtonDownFcn;
            end
            if isvalid(obj.hFigure)
                obj.hFigure.WindowButtonMotionFcn = obj.defaultFigureCallbacks.WindowButtonMotionFcn;
                obj.hFigure.WindowButtonUpFcn = obj.defaultFigureCallbacks.WindowButtonUpFcn;
            end
        end
        
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
                        
            % 1) Call default figure callback
            if ~isempty(obj.defaultFigureCallbacks.ButtonDownFcn)
                obj.defaultFigureCallbacks.ButtonDownFcn(src, event)
            end
            
            % 2) Call active pointer tool
            if obj.isCursorInsideAxes(obj.hAxes)
                if ~isempty(obj.currentPointerTool)
                    obj.currentPointerTool.onButtonDown(src, event)
                end
            end

        end
        
        
        function onButtonMotion(obj, src, event)
            
            % 1) Call default figure callback
            if ~isempty(obj.defaultFigureCallbacks.WindowButtonMotionFcn)
                obj.defaultFigureCallbacks.WindowButtonMotionFcn(src, event)
            end
            
            if isempty(obj.currentPointerTool); return; end
            
            tf = obj.isCursorInsideAxes(obj.hAxes);


            % Change cursor symbol when pointer enters or leaves axes
            if tf && ~obj.wasCursorInAxes % Entered axes
                if ~isempty(obj.currentPointerTool)
                    obj.currentPointerTool.setPointerSymbol()
                end
            elseif ~tf && obj.wasCursorInAxes % Left axes
                set(obj.hFigure, 'Pointer', 'arrow');
            end
            
            
            % Create extended eventdata containing mousepoint coordinates?

            
            
            % 2) Call active pointer tool
            if ~isempty(obj.currentPointerTool)% && ~isSuspended(obj.currentPointerTool) Some tools, like zoom, should continue to workeven when cusor moves outside axes...
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
            
            % 1) Call default figure callback
            if ~isempty(obj.defaultFigureCallbacks.WindowButtonUpFcn)
                obj.defaultFigureCallbacks.WindowButtonUpFcn(src, event)
            end
            
            % 2) Call active pointer tool
            if ~isempty(obj.currentPointerTool)
                obj.currentPointerTool.onButtonUp(src, event)
            end
            
        end
        

        function wasCaptured = onKeyPress(obj, src, event)
            
            % Todo: Make a system for having unique key shortcuts and
            % setting/changing them from on location..
            
            
            % 1) Call default figure callback
% %             if ~isempty(obj.defaultFigureCallbacks.KeyPressFcn)
% %                 obj.defaultFigureCallbacks.KeyPressFcn(src, event)
% %             end
            
            wasCaptured = true;
            
            if isempty(event.Modifier)
                switch event.Key
                    case 'q'
                        obj.togglePointerMode('zoomIn')
                    case 'w'
                        obj.togglePointerMode('zoomOut')
                    case 'y'
                        obj.togglePointerMode('pan')
                    case 'x'
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
    
    
    
end