classdef messageBox < uim.mixin.isResizable
%uim.widget.messageBox A class that implements a messagebox for showing
% popupmessages within a figure window. 
    

% TODO: 
%   [ ] Remove dependence on uim.mixin.isResizeable (imrect fucks up the axes configurations)


    properties (Access = private)

        hParent % which axes the msgbox axes is plotted relative to. its not a real parent, so should find a different name
        hAxes
        hBackground
        hText
        xButton
        xButtonBg
        OriginalPosition = [];
        
        hWaitbar
        isWaitbarActive = false
        
        currentObjectInFocus = struct('handle', gobjects(1), 'props', {{}})
        figureCursorMotionFcn = [];
        MouseMotionListener = event.listener.empty
        
        isMouseOver
        Value = 0
        Style = uim.style.buttonDarkMode
        
        MessageTimer
        CornerRadius = 2
    end
    
    properties
        %Parent %isResizable property for which axes the imrect is plotted into
        Position
        BackgroundColor = ones(1,3) * 0.2
        BackgroundAlpha = 0.7
        BorderColor = ones(1,3) * 0.5
        FontSize = 14
        FontColor = ones(1,3)*0.8
    end % \properties Dependent?
    
    properties (Dependent)
        Axes
    end
    
    properties
        Units = 'pixel'
        MinSize = [300, 50] % Should be MaxSize....
    end % \properties
    
    
    methods
    
        function obj = messageBox(hParent, varargin)
            
            msg = 'Invalid Sequence of Name, Value Parameters';
            assert(all(cellfun(@(arg) ischar(arg), varargin(1:2:end))), msg)
            
            for i = 1:2:numel(varargin)
                try
                    obj.(varargin{i}) = varargin{i+1};
                catch
                    fprintf('Invalid Parameter Name (%s)\n', varargin{i})
                end
            end
            
            % Todo: parse varargin...

            obj.hParent = hParent;

            obj.createAxes()
            obj.createTextbox()

            
        end % \messageBox (Constructor)
        
        function delete(obj)
            delete(obj.hAxes)
        end % \delete
        
        function h = get.Axes(obj)
            h = obj.hAxes;
        end
        
    end % \structor methods
        
    methods (Access = protected)
        function setDefaultButtonDownFcn(obj, fcnHandle)
        
        end
        
        function resize(obj, newPosition, ~)
            
            % make sure messagebox units are the same as the reference axes
            % units before setting the position property. The position
            % values are based on the Units property of the parent.
            
            axUnits = obj.hAxes.Units;
            obj.hAxes.Units = obj.hParent.Units;
            
            if strcmp(obj.Parent.XDir, 'reverse')
                newPosition(1) = obj.Parent.Position(3) - newPosition(1);
            end
        
            if strcmp(obj.Parent.YDir, 'reverse')
                newPosition(2) = obj.Parent.Position(4) - newPosition(2);
            end
            
            obj.hAxes.Position = newPosition;
            obj.hAxes.Units = axUnits;
            
            obj.updateTextboxCoords()
        end
    end
    
    methods (Access = private)
        
        function createAxes(obj)
           
            % Add message axes...
            if isa(obj.hParent, 'matlab.graphics.axis.Axes')
                obj.hAxes = axes('Parent', obj.hParent.Parent);
            else
                obj.hAxes = axes('Parent', obj.hParent);
            end
        

            % Set some axes properties
            obj.hAxes.Units = obj.Units;
            obj.hAxes.HandleVisibility = 'off';
            obj.hAxes.Tag = 'Message Box';

            % Get parent position
            origParentUnits = obj.hParent.Units;
            obj.hParent.Units = obj.Units;
            pos = obj.hParent.Position;
            obj.hParent.Units = origParentUnits;
            
            if isa(obj.hParent, 'matlab.ui.Figure') || isa(obj.hParent, 'matlab.ui.container.Panel')
                pos(1:2)=0;
            end

            % Make sure axes does not exceed parent container.
            axW = min(pos(3), obj.MinSize(1));
            axH = min(pos(4), obj.MinSize(2));
            
            axesLocation = [pos(1)+ (pos(3) - axW)/2, pos(2) + (pos(4) - axH)/2];
            obj.hAxes.Position = [axesLocation, axW, axH ];
            obj.hAxes.Visible = 'off';
            hold(obj.hAxes, 'on')
            
            if isa(obj.hParent, 'matlab.ui.container.Panel')
                obj.hAxes.Position = [0,0,obj.hParent.Position(3:4)];
            end
            

            
            % Configure isResizable behavior. This will make the messagebox
            % resizeable.
            axUnits = obj.hAxes.Units;
            obj.hAxes.Units = obj.hParent.Units;
            obj.Position = obj.hAxes.Position;
            obj.hAxes.Units = axUnits;
                        
            obj.Parent = obj.hParent;
            if isa(obj.hParent, 'matlab.graphics.axis.Axes')
                obj.createInteractiveRectangle()
                obj.hideInteractiveRectangle
                
                hFunc = makeConstrainToRectFcn('imrect', obj.Parent.XLim, obj.Parent.YLim);
                obj.setPositionConstraintFcn(hFunc)
                obj.isResizeable = false; % Turn of resizeability. (Messagebox can only be moved).
            end
            
        end % \createAxes
    
        function [xData, yData] = getTextboxCoordinates(obj)
                       
% %             % Deprecate:
% %             xLim = obj.hAxes.XLim;
% %             yLim = obj.hAxes.YLim;
% % 
% %             xData = xLim([1,1,2,2,1]);
% %             yData = yLim([2,1,1,2,2]);
            
            axesPos = getpixelposition(obj.hAxes);
            boxSize = axesPos(3:4);
            [xData, yData] = uim.shape.rectangle(boxSize, obj.CornerRadius);
            xData = xData / max(xData(:));
            yData = yData / max(yData(:));
            
            
        end
        
        function updateTextboxCoords(obj)
            if isempty(obj.hBackground); return; end
            [xData, yData] = obj.getTextboxCoordinates();
            set(obj.hBackground, 'XData', xData, 'YData', yData)
        end
        
        function createTextbox(obj)
            
            [xData, yData] = obj.getTextboxCoordinates();
            
            obj.hBackground = patch(obj.hAxes, xData, yData, 'w');
            obj.hBackground.FaceColor = obj.BackgroundColor;
            obj.hBackground.FaceAlpha = obj.BackgroundAlpha;
            obj.hBackground.EdgeColor = obj.BorderColor;
            obj.hBackground.Visible = 'off';
            obj.hBackground.PickableParts = 'none';
            obj.hBackground.HitTest = 'off';

            hold(obj.hAxes, 'on')
            obj.hAxes.XLim = [0,1];
            obj.hAxes.YLim = [0,1];

            xPos = obj.hAxes.XLim(1) + range(obj.hAxes.XLim)/2;
            yPos = obj.hAxes.YLim(1) + range(obj.hAxes.YLim)/2;

            obj.hText = text(obj.hAxes, xPos, yPos, '');
            obj.hText.Visible = 'off';
            obj.hText.HorizontalAlignment = 'center';
            obj.hText.VerticalAlignment = 'middle';
            obj.hText.FontSize = obj.FontSize;
            obj.hText.Color = obj.FontColor;
            obj.hText.Interpreter = 'none';
            obj.hText.PickableParts = 'none';
            obj.hText.HitTest = 'off';
            
            % Add button.
            obj.xButton = plot(obj.hAxes, 1, 1, 'x');
            obj.xButton.MarkerSize = 12;
            obj.xButton.Visible = 'off'; 
            obj.xButton.ButtonDownFcn = @(s,e) obj.clearMessage;
            obj.xButton.Color = obj.FontColor;
            obj.xButton.LineWidth = 1;
            obj.xButton.PickableParts = 'visible';
            obj.xButton.HitTest = 'on';
            
            obj.setXbuttonPosition()
            obj.addXbuttonBackground()
            
            pointerBehavior.enterFcn    = @obj.onMouseEnteredButton;
            pointerBehavior.exitFcn     = @obj.onMouseExitedButton;
            pointerBehavior.traverseFcn = [];%@obj.moving;
            
            iptSetPointerBehavior(obj.xButton, pointerBehavior);
            iptPointerManager(ancestor(obj.xButton, 'figure'));
            uistack(obj.xButton, 'top')
            
        end % \createTextbox

        
        function setXbuttonPosition(obj)
            pixpos = getpixelposition(obj.hAxes);
            btnPos = 1 - ([0.05, 0.05] .* [1, pixpos(3)/pixpos(4)]);
            obj.xButton.XData = btnPos(1);
            obj.xButton.YData = btnPos(2);

            if ~isempty(obj.xButtonBg)
                [xData, yData] = obj.getXButtonBackgroundCoords();
                set(obj.xButtonBg, 'XData', xData, 'YData', yData)
            end
                
        end
        
        
        function addXbuttonBackground(obj)
            

            [xData, yData] = obj.getXButtonBackgroundCoords();
            hBtn = patch(obj.hAxes, xData, yData, 'w');

            % Configure patch which will be visible when hovering over X
            hBtn.FaceColor = [209, 210, 211] ./ 255;
            hBtn.EdgeColor = 'none';
            hBtn.FaceAlpha = 0.01;
            hBtn.LineWidth = 1;
            hBtn.Tag = sprintf('Close Button');
            hBtn.ButtonDownFcn = @(s, e) obj.clearMessage;
            hBtn.HitTest = 'off';
            hBtn.PickableParts = 'none';
            hBtn.Visible = 'off'; 

            obj.xButtonBg = hBtn;

        end
        
        function [xData, yData] = getXButtonBackgroundCoords(obj)
            
            margin = 6;
            offset = 0;
                        
            % Get coordinates for patching a box under the X.
            bgSize = obj.xButton.MarkerSize + margin;
            [edgeX, edgeY] = uim.shape.rectangle([bgSize, bgSize]);
            edgeX = edgeX + offset;
                
            % Convert edge coordinates to data units (Transpose because
            % input to px2du is nPoints x 2 and output from createBox is 
            % row-vectors.
            edgeCoords = uim.utility.px2du(obj.hAxes, [edgeX', edgeY'] );
            xPos = obj.xButton.XData;
            yPos = obj.xButton.YData;

            % Shift coordinates to be centered on xPos and yPos.
            edgeCoords = edgeCoords - mean(edgeCoords,1) + [xPos, yPos];
            
            xData = edgeCoords(:, 1);
            yData = edgeCoords(:, 2);
            
        end
        
        
        function fadeIn(obj)
            obj.hBackground.FaceAlpha = 0;
            obj.hBackground.Visible = 'on';
            
            fade = linspace(0, obj.BackgroundAlpha, 60);

            for i = 1:numel(fade)
                obj.hBackground.FaceAlpha = fade(i);
                if i == 10
                    obj.hText.Visible = 'on';
                    obj.xButton.Visible = 'on';
                    obj.xButtonBg.Visible = 'on';
                end
                pause(0.01)
                drawnow limitrate
            end

        end % \fadeIn
        
        
        function fadeOut(obj)
    
            fade = linspace(obj.BackgroundAlpha, 0, 60);

            for i = 1:numel(fade)
                obj.hBackground.FaceAlpha = fade(i);
                if i == 50
                    obj.hText.Visible = 'off';
                    obj.xButton.Visible = 'off';
                    obj.xButtonBg.Visible = 'off';
                end
                pause(0.01)
                drawnow limitrate
            end

        end % \fadeOut
        
        
        function foldMessage(obj)
            
            msg = obj.hText.String;

            
            nChars = numel(msg);
            extent = obj.hText.Extent;
            obj.hText.String = '';

            nLines = ceil(extent(3)); 
            %Extent is in normalized units, so the extent says how many
            %lines the text should be divided on.
            
            
            nCharsPerLine = floor(nChars ./ extent(3) ) - 10; % -10 to leave some margin

            % Start loop where message is split on spaces to create lines
            % that will not exceed the width of the textbox. Loop finished
            % when it has gone over the whole message. Note: Messages are
            % also split on file separator, so that long pathstrings are
            % also split
                  
            % Todo: Improve/simplify code.
            
            tmpmsg = msg;
            lines = cell(nLines, 1);
            finished = false;
            c = 1;
            while ~finished
                [split, M] = strsplit(tmpmsg, {filesep, ' '});
                M{end+1} = '';
                a = cumsum( arrayfun(@(i) numel(split{i}) + i-1, 1:numel(split) ) );
                b = a-nCharsPerLine;
                b(b>0) = [];
                [~, ind] = max(b);

                lines{c} = strjoin( cat(1, split(1:ind), M(1:ind)), '');
                tmpmsg = strjoin( cat(1, split(ind+1:end), M(ind+1:end)), '');
                c = c + 1;
                if isempty(tmpmsg); finished = true; end
            end

            obj.hText.Interpreter = 'none';
            obj.hText.String = lines;
            extent = obj.hText.Extent;

            if extent(4) > 1
                obj.OriginalPosition = obj.hAxes.Position([2,4]);
                obj.hAxes.Position(4) = obj.hAxes.Position(4) * ceil(extent(4));
                obj.hAxes.Position(2) = obj.hAxes.Position(2) - ...
                    (obj.hAxes.Position(4) - obj.OriginalPosition(2))/2;
                obj.setXbuttonPosition()
                obj.updateTextboxCoords()
            end

        end % \foldMessage
        
        
% %         function hijackMouseOver(obj)
% %             hFig = ancestor(obj.hParent, 'Figure');
% %             
% %             if isempty(obj.MouseMotionListener)
% %                 el = listener(hFig, 'WindowMouseMotion', @obj.mouseOver);
% %                 obj.MouseMotionListener = el;
% %             end
% %             
% %         end
        
% %         function giveBackMouseOver(obj)            
% %             if ~isempty(obj.MouseMotionListener)
% %                 delete(obj.MouseMotionListener);
% %                 obj.MouseMotionListener = event.listener.empty;
% %             end
% %         end
        
        
% %         function mouseOver(obj, src, event)
% %             %disp('messageBox mouseover')
% %              h = hittest();
% % %             
% % %             if ~isequal(h, obj.currentObjectInFocus.handle)
% % %                 % Reset previous object
% % %                 if ~isa(obj.currentObjectInFocus.handle, 'matlab.graphics.GraphicsPlaceholder')
% % %                     set(obj.currentObjectInFocus.handle, obj.currentObjectInFocus.props{:})
% % %                     obj.currentObjectInFocus = struct('handle', gobjects(1), 'props', {{}});
% % %                 end
% % % 
% % %                 if isa(h, 'matlab.graphics.primitive.Patch') && contains(h.Tag, 'Button')
% % %                     h.FaceAlpha = 0.15;
% % %                     obj.currentObjectInFocus = struct('handle', h, 'props', {{'FaceAlpha', 0}});
% % %                 end
% % %             end
% %             
% %             
% %             if isequal(h, obj.xButtonBg)
% %             	% Already taken care of
% %             elseif isequal(h, obj.hBackground) || isequal(h, obj.hText)
% %                 % Do nothing
% %             else % Call figures default callback...
% %                 if ~isempty(obj.figureCursorMotionFcn)
% %                     obj.figureCursorMotionFcn(src, event)
% %                 end
% %             end
% % 
% %         end


        function clearMessageIn(obj, n, doFade)
            
            if ~isempty(obj.MessageTimer)
                stop(obj.MessageTimer)
                delete(obj.MessageTimer)
                obj.MessageTimer = [];
            end
            n = round(n, 2);
            t = timer('ExecutionMode', 'singleShot', 'StartDelay', n);
            t.TimerFcn = @(myTimerObj, thisEvent, tf) obj.clearMessageByTimer(t, doFade);
            obj.MessageTimer = t;
            start(obj.MessageTimer)
        end
        
        
        function clearMessageByTimer(obj, t, doFade)
            
            % Return if gui has been deleted
            if ~isvalid(obj); return; end
            
            if nargin >=2 && ~isempty(t) && isvalid(t)
                stop(obj.MessageTimer)
                delete(obj.MessageTimer)
                obj.MessageTimer = [];
            end
            
            obj.clearMessage(doFade)
            
        end
        
        
            function onMouseEnteredButton(obj, hSource, eventData)
                obj.isMouseOver = true;
                obj.xButtonBg.FaceAlpha = 0.15;
                obj.xButtonBg.EdgeColor = ones(1,3) * 0.4;

    %             if ~isempty(obj.Tooltip)
    %                 obj.Toolbar.showTooltip(obj.Tooltip, obj.TooltipPosition)
    %             end
            end


            function onMouseExitedButton(obj, hSource, eventData)
                obj.isMouseOver = false;
                obj.xButtonBg.FaceAlpha = 0;
                obj.xButtonBg.EdgeColor = 'none';

    %             obj.Toolbar.hideTooltip()

            end
            

        
        
    end % \methods (Private)
    
    methods (Access = public)

        function centerInWindow(obj, pos)
            uim.utility.layout.centerObjectInRectangle(obj.Axes, pos)
        end
        
        function activateGlobalMessageDisplay(obj, mode)
        
            if nargin < 2
                mode = 'update';
            end

            global fprintf

            switch mode
                case 'display'
                    fprintf = @(msg)obj.displayMessage(msg);
                case 'update'
                    fprintf = @(varargin)obj.displayMessage(varargin{:});
            end

        end
        
        function activateGlobalWaitbar(obj)
            global waitbar
            waitbar = @obj.waitbar;
        end
        
        function deactivateGlobalWaitbar(obj)
         	global waitbar
            waitbar = [];
            
            obj.waitbar(1, '', 'close')
        end
        
        function displayMessage(obj, msg, duration, doFade)

            if isempty(obj); return; end
            
            if nargin < 4; doFade = false; end

            %             if nargin < 3 || isempty(duration)
            %                 duration = 2;
            %             end

            % Do this first, to avoid double calling if two messages are
            % displayed quickly.
            %obj.hijackMouseOver()

            msg = sprintf('%s', msg);
            msg = strrep(msg, newline, '');
            
            if ~isempty(obj.hText.String)
                if isequal(msg, obj.hText.String{1}); return; end
            end
            
            % todo, do more work on this... i.e 
            % this function should accept everything that can go into
            % fprintf
            
            obj.hText.String = msg;
            obj.foldMessage()
            
            if doFade && ~strcmp(obj.hBackground.Visible, 'on')
                obj.fadeIn()
            else
                obj.hText.Visible = 'on';
                obj.hBackground.Visible = 'on';
                obj.xButton.Visible = 'on';
                obj.xButtonBg.Visible = 'on'; 
        
                drawnow
            end
            obj.showInteractiveRectangle()
            
            if isa(obj.hParent, 'matlab.ui.container.Panel')
                obj.hParent.Visible = 'on';
            end
            
            
            
            % Make sure close-button background is will capture
            % mouseclicks/mouseovers.
% %             obj.xButtonBg.HitTest = 'on';
% %             obj.xButtonBg.PickableParts = 'all';
            
            if nargin >= 3 && ~isempty(duration)
                obj.clearMessageIn(duration, doFade)

%                 pause(duration)
%                 obj.clearMessage(doFade)
            end
            
            
        end % \displayMessage
        
        function clearMessage(obj, doFade)

            if isempty(obj); return; end
            
            if nargin < 2; doFade = false; end
            
            if doFade
                obj.fadeOut();
                obj.hBackground.FaceAlpha = obj.BackgroundAlpha;
            else
                obj.hText.Visible = 'off';
                obj.xButton.Visible = 'off';
                obj.xButtonBg.Visible = 'off';
            end
            obj.hideInteractiveRectangle()

            obj.hText.String = '';
            obj.hBackground.Visible = 'off';
            
            % Make sure close-button background is will not capture
            % mouseclicks/mouseovers.
% %             obj.xButtonBg.HitTest = 'off';
% %             obj.xButtonBg.PickableParts = 'visible';
            
            if ~isa(obj.currentObjectInFocus.handle, 'matlab.graphics.GraphicsPlaceholder')
                set(obj.currentObjectInFocus.handle, obj.currentObjectInFocus.props{:})
                obj.currentObjectInFocus = struct('handle', gobjects(1), 'props', {{}});
            end
            
            if ~isempty(obj.OriginalPosition)
                obj.hAxes.Position([2,4]) = obj.OriginalPosition;
                obj.updateTextboxCoords()

                obj.OriginalPosition = [];
                obj.setXbuttonPosition()
            end

            if obj.isWaitbarActive && ~isempty(obj.hWaitbar)
                obj.waitbar(1, '', 'close')
            end
            
            if isa(obj.hParent, 'matlab.ui.container.Panel')
                obj.hParent.Visible = 'off';
            end
            
            %drawnow
            %%obj.giveBackMouseOver()

        end % \clearMessage
        
        function tf = isMessageDisplaying(obj)
            tf = strcmp(obj.hText.Visible, 'on') && ~isempty(obj.hText.String);
        end
        
        function resetAxesPosition(obj)
            
             % Get parent position
            origParentUnits = obj.hParent.Units;
            obj.hParent.Units = obj.Units;
            pos = obj.hParent.Position;
            obj.hParent.Units = origParentUnits;
            
            if isa(obj.hParent, 'matlab.ui.Figure')
                pos(1:2)=0;
            end

            % Make sure axes does not exceed parent container.
            axW = min(pos(3), obj.MinSize(1));
            axH = min(pos(4), obj.MinSize(2));

            axesLocation = [pos(1)+ (pos(3) - axW)/2, pos(2) + (pos(4) - axH)/2];
            obj.hAxes.Position = [axesLocation, axW, axH ];
            obj.updateTextboxCoords()

        end
        
    end % \methods
    
    
    methods (Access = public) % Waitbar
        
        
        function waitbar(obj, p, message, action)
            
            if nargin < 3; message = ''; end
            if nargin < 4; action = 'set'; end
            
            
            if isempty(obj.hWaitbar) % Create waitbar
                pixPos = getpixelposition(obj.hAxes);
                obj.hWaitbar = uim.widget.Waitbar(obj.hAxes, ...
                    'Position', [0,1,pixPos(3),10], 'Visible', 'off');
            end
            
            
            switch action
                case 'close' 
                    obj.isWaitbarActive = false;
                    obj.hWaitbar.Status = 0; % Reset status
                    obj.hWaitbar.Visible = 'off';
                    
                otherwise

                    if ~obj.isWaitbarActive % Activate waitbar
                        obj.isWaitbarActive = true;
                        obj.hWaitbar.Visible = 'on';
                        drawnow
                    end
                    
                    p = min([p,1]);
                    obj.hWaitbar.Status = p;

                    if ~isempty(message)
                        obj.displayMessage(message)
                    end
            end            
            
        end


        
    end
    
    
end % \classdef

