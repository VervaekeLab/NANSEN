classdef uicontrolSchemer < handle
    
%   Works with:
%       checkbox - remove icon and plot checkbox % todo: make uim.control
%       edit - remove border and plot new border
%       popupmenu - adds two dummy uicontrols on top (text+button)
%       text - remove border and plot new border
%       pushbutton - remove border and plot new border
%
%   Not supported yet
%       listbox
%       radiobutton
%       slider
%       togglebutton
    
% Note: - Sometimes, the checkbox is not working....
%       - If popupmenu size is small, the textbox does not cover properly.
%       - Add options from creating textbox with transparent background...
%       - If units of uicontrols are normalized, make sure units or newly
%         created "dummy" controls are normalized.
%       - glitch with popupmenu, where it sometimes becomes visible very
%       briefly.

%   Todo: Set colors dynamically based on figure/panel background and
%   foreground colors.
    
    properties(Access = private)
       
        hPanel          % Panel which uicontrols are parented to.
        hAxes           % Axes where uicontrol visualizations are plotted
        
        hUicontrol      % Handles for uicontrols. (Not in use)
        jhUicontrol     % Java Handles for uicontrols. (Not in use)
        
        checkboxIcon = []
        
        ParentContainerSizeChanged
        FigureDestroyedListener
    end
    
    
    properties
        borderColor = [209, 210, 211] ./ 255
        highlightColor = [0.9454    0.8998    0.1127]
        
        cornerRadius = 5
        
        checkboxSize = [14, 14] % Pixels (14,14)

    end
    
    
    
    methods
        
        function obj = uicontrolSchemer(hUIControls, hPanel, colorTheme)
            
            % Get parent of uicontrol
            if nargin < 2 || isempty(hPanel)
%                 obj.hPanel = hUIControls(1).Parent;
                obj.hPanel = ancestor(hUIControls(1), 'uipanel');
                if isempty(obj.hPanel)
                    error('The uicontrol must be located in a panel for uicontrolSchemer to work.')
                end
            else
                obj.hPanel = hPanel;
            end
            
% % %             % For debugging...
% % %             varName = sprintf('uischemer%05d', randi(10000));
% % %             assignin('base', varName, obj)
            
            obj.ParentContainerSizeChanged = addlistener(obj.hPanel, ...
                'SizeChanged', @obj.onPanelSizeChanged);
            
            obj.FigureDestroyedListener = listener(ancestor(obj.hPanel, 'figure'), ...
            'ObjectBeingDestroyed', @obj.delete);
            
            obj.initializeStylerAxes()
            
            cmap = magma(255);
            obj.highlightColor = cmap(randi([128,255], 1), :);
            
            findjavacomps = @applify.uicontrolSchemer.findJavaComponents;
            javaHandles = findjavacomps(hUIControls, obj.hPanel);
                        

            if isempty(javaHandles) || numel(javaHandles) ~= numel(hUIControls)
                return %Abort
            end
            
% % %             % Assign handle of uicontrol to obj
            obj.hUicontrol = hUIControls;
            obj.jhUicontrol = javaHandles;
            
            
            numUIControls = numel(hUIControls);
            for i = 1:numUIControls
                hTmp = hUIControls(i);
                jTmp = javaHandles{i};
                
                origUnits = hTmp.Units;
                hTmp.Units = 'pixel';
                
                obj.stripUicontrol(hTmp, jTmp);

                hS = obj.addExtras(hTmp, jTmp);
                hS = obj.createBorder(hTmp, jTmp, hS);
                
                obj.configureInteractivityCallbacks(hTmp, jTmp, hS);
                
%                 obj.hUicontrol.DeleteFcn = @obj.deleteStyle;
                
                hTmp.Units = origUnits;

            end

            
            if ~nargout
                clear obj
            end
            
        end
        
        function delete(obj, ~, ~)
            if ~isvalid(obj); return; end
            delete(obj.FigureDestroyedListener)
            delete@handle(obj) % Why does this have to be explicit?
        end
        
        
        function onPanelSizeChanged(obj, src, evt)    
                        
            numUIControls = numel( obj.hUicontrol );
            for i = 1:numUIControls

                hTmp = obj.hUicontrol(i);
                jTmp = obj.jhUicontrol{i};
                
                if strcmp( hTmp.Style, 'checkbox')
                    bgColor = hTmp.Parent.BackgroundColor;

                    % Reset icon of control's java object.
                    %jTmp.setIcon(obj.checkboxIcon);
                    hTmp.CData = ones(1,1,3).*reshape(bgColor, 1,1,3);
                    % Make sure object is transparent
                    set(jTmp, 'Opaque', false)
                
                elseif strcmp( hTmp.Style, 'popupmenu')
                    bgColor = hTmp.Parent.BackgroundColor;

                    % Reset icon of control's java object.
                    %jTmp.setIcon(obj.checkboxIcon);
                    hTmp.CData = ones(1,1,3).*reshape(bgColor, 1,1,3);
                    % Make sure object is transparent
                    set(jTmp, 'Opaque', false)
                    
                    hS = hTmp.UserData;

% %                     findjavacomps = @applify.uicontrolSchemer.findJavaComponents;
% %                     jhBtn = findjavacomps(hS.button, hTmp.Parent);
% %                     obj.stripUicontrol(hS.button, jhBtn{1})
                    
                elseif strcmp( hTmp.Style, 'pushbutton')  || strcmp( hTmp.Style, 'togglebutton')
                    set(jTmp, 'BorderPainted', 0);
                    set(jTmp, 'Opaque', 0)
                    set(jTmp, 'ContentAreaFilled', 0)
                    hTmp.CData = ones(1,1,3).*reshape(bgColor, 1,1,3);
                    drawnow
                end
                
            end
            
        end
        
        function onButtonResized(obj, src, evt)
            set(src, 'BorderPainted', 0)
            set(src, 'Opaque', 0)
            set(src, 'ContentAreaFilled', 0)
            %pause(0.01)
            %disp(rand)
            %drawnow limitrate
        end
        
        function stripUicontrol(obj, hControl, jControl)
        % Remove all unnecessary features of the original design
        %
        %   Editbox. Set background color and remove border
        %
        %   Checkbox. Set transparent icon. Later, all visible features 
        %   of the checkbox is plotted in the stylerAxes.
        %
        %   Popupmenu: Set background. Remove focusability.
        
                
            bgColor = hControl(1).Parent.BackgroundColor;
            javacolor = @javax.swing.plaf.ColorUIResource;
            
            
            % Remove Default Border
            switch hControl.Style
                
                case 'text'
%                     hControl.BackgroundColor = bgColor;
                    set(jControl, 'Opaque', 0)
                    
                case 'edit'

                    % Set background color.
                    hControl.BackgroundColor = bgColor;
                    
                    % Create a border with same color as background. 
                    % Maybe easier to remove border completely?
                    jColor = javacolor(bgColor(1), bgColor(2), bgColor(3));
                    newBorder = javax.swing.BorderFactory.createLineBorder(jColor, 1);
                    jControl.setBorder(newBorder)
                    
                case {'pushbutton', 'togglebutton'}
                    %hControl.BackgroundColor = [40   40   40]/255;
                    set(jControl, 'BorderPainted', 0);
                    set(jControl, 'Opaque', 0)
                    set(jControl, 'ContentAreaFilled', 0)
                    set(jControl, 'border', []);

                    % Need a callback for when ancestor is resized, because
                    % on windows the button appearance resets everytime the
                    % ancestor is resized
                    jControl = handle(jControl, 'CallbackProperties');
                    set(jControl, 'AncestorResizedCallback', @obj.onButtonResized)
                    set(jControl, 'AncestorMovedCallback', @obj.onButtonResized)
                    
                case 'checkbox'
                    
                    % Need to do this before removing icon. Maybe updating
                    % hControl properties resets the icon???
                    hControl.Position(3) = hControl.Position(4);
                    drawnow;
                    
                    % Create Icon which is the same color as background
                    if isempty(obj.checkboxIcon)
                        iconData = ones(20,20,3) .* reshape(bgColor, 1, 1, 3);
                        tmpIconFile = [tempname, '.png'];
                        imwrite(iconData, tmpIconFile, 'PNG', 'Transparency', bgColor)
                        obj.checkboxIcon = javax.swing.ImageIcon(tmpIconFile);
                        delete(tmpIconFile)
                    end
                    
                    % Reset icon of control's java object.
                    jControl.setIcon(obj.checkboxIcon);
                    
                    % Make sure object is transparent
                    set(jControl, 'Opaque', false)
                    
                    
                case 'popupmenu'
                    
                    hControl.BackgroundColor = bgColor;
                    jControl = handle(jControl, 'CallbackProperties');
                    
                    jControl.Focusable = 0;
                    set(jControl, 'Opaque', 0)
                    set(jControl, 'Border', []);

                otherwise
                    fprintf('Not implemented yet\n')
                
            end
            
        end
        
        function removeJButtonStyling(obj, jControl)
            set(jControl, 'BorderPainted', 0);
            set(jControl, 'Opaque', 0)
            set(jControl, 'ContentAreaFilled', 0)
        end
            
        
        function hS = addExtras(obj, hControl, jControl, hS)
            
            if nargin < 4 || isempty(hS)
                hS = struct;
            end

            
            switch hControl.Style
                
                case 'popupmenu'
                     % Create inactive textbox on top of popupmenu.
                     % Make sure text in textbox is updated according to
                     % popup....
                     % Create button to indicate popup can be expanded.

                     % Show/hide popupmenu when control is pressed / loses
                     % focus.
                     
% % %                             inputbox = uim.control.Button_(guiPanel, ...
% % %                                 'mode', 'pushbutton', config.args{:}, ...
% % %                                 'HorizontalTextAlignment', 'center');
                     

                    
                     
                    hS.textBox = uicontrol(hControl.Parent, 'style', 'text');
                    hS.textBox.Position = hControl.Position;
                                        
                    hS.textBox.ForegroundColor = hControl.ForegroundColor;
                    hS.textBox.HorizontalAlignment = 'left';
                    hS.textBox.FontName = hControl.FontName;
                    hS.textBox.FontSize = hControl.FontSize;
                    hS.textBox.String = hControl.String{hControl.Value};

                    
                    bgColor = hS.textBox.Parent.BackgroundColor;
                    javacolor = @javax.swing.plaf.ColorUIResource;
                    hS.textBox.BackgroundColor = bgColor;

                    hS = createBorder(obj, hS.textBox, [], hS, true);
                    
                    % Adjust y position of textedit uicontrol to maintain
                    % vertical centering within the modified control box.
                    deltaY = (hS.textBox.Position(4) - hS.textBox.Extent(4))/2;
                    hS.textBox.Position(2) = hS.textBox.Position(2) + deltaY ;
                    hS.textBox.Position(4) = hS.textBox.Extent(4);
                    
                    % Add some padding within the textbox
                    textboxPadding = [3, 25];
                    hS.textBox.Position(1) = hS.textBox.Position(1)+textboxPadding(1);
                    hS.textBox.Position(3) = hS.textBox.Position(3)-textboxPadding(2);
                    
                    
                    % Create a new button to replace the original hControl
                    hS.button = uicontrol(hControl.Parent, 'style', 'pushbutton');
                    hS.button.Position = hControl.Position;
                    hS.button.ForegroundColor = hControl.ForegroundColor;
                    hS.button.FontName = hControl.FontName;
                    hS.button.FontSize = hControl.FontSize;
                    
                    % Brute force placement of button symbol...
                    while hS.button.Extent(3) < hControl.Position(3)-15
                        hS.button.String(end+1) = ' ';
                    end
                    hS.button.String(end+1) = 'v';
                    
                    
                    % Configure button...
                    findjavacomps = @applify.uicontrolSchemer.findJavaComponents;
                    jhBtn = findjavacomps(hS.button, hControl.Parent);
                    obj.stripUicontrol(hS.button, jhBtn{1})

    
                    % Make sure text does not go too far to the right, e.g
                    % outside of the box, or under the popupmenu button
                    obj.keepTextWithinBox(hS.textBox)
                    

                    % Add callback so text in edit control updates when ui 
                    % control value changes.
                    addlistener(hControl, 'Value', 'PostSet', ...
                        @(s,e, hC, h) obj.updatePopup(hControl, hS.textBox));
                    
                    addlistener(hControl, 'String', 'PostSet', ...
                        @(s,e, hC, h) obj.updatePopup(hControl, hS.textBox));

                    
                    set(jhBtn{1}, 'MousePressedCallback', @(s, e, h) obj.clickedPopupButton(jControl, hControl))
                    set(jhBtn{1}, 'MouseEnteredCallback', @(s, e) obj.mouseEnterPopupButton(hS.button))
                    set(jhBtn{1}, 'MouseExitedCallback', @(s,e) obj.mouseLeavePopupButton(hS.button))
                    set(jhBtn{1}, 'FocusGainedCallback', @(s, e, hc, h) obj.gainFocus(hControl, hS) )
                    set(jhBtn{1}, 'FocusLostCallback', @(s, e, hc, h) obj.loseFocus(hControl, hS) )
                    jhBtn{1}.setCursor(java.awt.Cursor(java.awt.Cursor.HAND_CURSOR))
                    
                    
                    if false % for debugging
                        hS.button.Visible = 'off';
                        hS.textBox.Visible = 'off';
                    else
                        hS.button.Visible = 'on';
                        hS.textBox.Visible = 'on';
                    end
                    
                    % Width to zero to hide this ugly beast.
                    hControl.Position(3) = 0;
            end
            
        end
        
        
        function hS = createBorder(obj, hControl, ~, hS, force)
            
        %    hS is a struct containing handles to graphical objects that
        %    are plotted for the control
        
            if nargin < 4 || isempty(hS)
                hS = struct;
            end
        
            if nargin < 5
                force = false;
            end
            
            
            if contains(hControl.Style, {'popupmenu', 'text'}) && ~force
                % No border on popup, because it will be underneath editbox
                return
            end
            
            
            % Get uicontrol position
            origUnits = hControl.Units;
            hControl.Units = 'pixel';
            uicPos = hControl.Position;
            hControl.Units = origUnits;
            
            
            % Get coordinates for a border around the uicontrol. xLoc and
            % yLox is the lower-left point of the border box.
            xLoc = uicPos(1);
            yLoc = uicPos(2);
            
            margin = [4,4];
            
            if contains(hControl.Style, 'checkbox')
                boxSize = obj.checkboxSize;
                yLoc = yLoc + (uicPos(4) - boxSize(2) - margin(2)) / 2 + 1;
            elseif contains(hControl.Style, 'pushbutton')
                boxSize = uicPos(3:4);
            else
                boxSize = uicPos(3:4);
            end
            
            boxSizeA = round( boxSize + margin);
            edgeCoords = uim.shape.rectangle(boxSizeA, obj.cornerRadius);
            edgeCoords = edgeCoords - min(edgeCoords);
            
            % Shift coordinates to location.
            % Had to subtract 1 pixel in x&y to get box in right position.
            % I have no idea why (Java Positions??).
            
            switch hControl.Style % attempt fix bug with button 
                case 'pushbutton'
                    edgeCoords = edgeCoords + [xLoc, yLoc] - [0, margin(2)]/2 - [1,1];
                otherwise
                    edgeCoords = edgeCoords + [xLoc, yLoc]  - margin/2 - [1,1];
            end
            
            % Plot & configure patch which will be visible border 
            hS.hBorder = patch(obj.hAxes, edgeCoords(:,1), edgeCoords(:,2), 'w');
            hS.hBorder.FaceColor = obj.borderColor;
            hS.hBorder.EdgeColor = obj.borderColor * 0.5;
            hS.hBorder.LineWidth = 1;
            hS.hBorder.FaceAlpha = 0;
            hS.hBorder.HitTest = 'off';
            hS.hBorder.PickableParts = 'none';
            
            switch hControl.Style % attempt fix bug with button 
                case {'pushbutton', 'togglebutton'}
                    hS.hBorder.FaceAlpha = 0.1;
                    hControl.ForegroundColor = ones(1,3)*0.8;
            end
            
            % Create a slightly bigger box
            margin2 = margin+2;
            boxSizeB = round( boxSize + margin2);
            edgeCoords = uim.shape.rectangle(boxSizeB, obj.cornerRadius);
            edgeCoords = edgeCoords + [xLoc, yLoc] - margin2/2 - [1, 1];
            edgeCoords(end+1, :) = edgeCoords(1, :); %Complete the "circle"
            
            % Configure line which will be visible when hovering over X
            hS.hAmbience = plot(obj.hAxes, edgeCoords(:,1), edgeCoords(:,2));
            hS.hAmbience.Color = [obj.highlightColor, 0.3]; % +Set alpha
            hS.hAmbience.LineWidth = 3;
            hS.hAmbience.Visible = 'off';
            hS.hAmbience.HitTest = 'off';
            hS.hAmbience.PickableParts = 'none';
            
            % Plot the tick mark in the checkbox.
            if contains(hControl.Style, 'checkbox')
                
                centerPos = boxSize/2 + [xLoc, yLoc] - [1.1, 1.1];
                hS.checkboxTick = plot(obj.hAxes, centerPos(1), centerPos(2), 'xr');
                hS.checkboxTick.LineWidth = 1.5;
                hS.checkboxTick.Color = obj.borderColor;
                hS.checkboxTick.MarkerSize = 9;
                hS.checkboxTick.HitTest = 'off';
                hS.checkboxTick.PickableParts = 'none';
                
                if hControl.Value
                    hS.checkboxTick.Visible = 'on';
                else
                    hS.checkboxTick.Visible = 'off';
                end
                
                
            end
        end
        
        
        function initializeStylerAxes(obj)
        %initializeStylerAxes Create axes for plotting uicontrol styles.
        
            % Check if there is an axes which can be used for plotting
            % styling gobjects into.Use findall, since style axes handle
            % visibility should be off.
            hAx = findall(obj.hPanel, 'Type', 'Axes', '-and', ...
                                        'Tag', 'UicStylerAxes');
            
            % Create axes if it is not present.
            if isempty(hAx)
                hAx = axes('Parent', obj.hPanel);
                hAx.Position = [0, 0, 1, 1];

                hAx.HandleVisibility = 'off';
                hAx.Visible = 'off';
                hAx.Units = 'pixel';
                hAx.Tag = 'UicStylerAxes';

                axSize = hAx.Position(3:4);
                set(hAx, 'XLim', [0, axSize(1)], 'YLim', [0, axSize(2)])
                hold(hAx, 'on')
            end
            
            obj.hAxes = hAx;

        end
        
        
        function configureInteractivityCallbacks(obj, hControl, jControl, hS)
            
            if contains(hControl.Style, {'pushbutton', 'togglebutton'})
                set(jControl, 'MouseEnteredCallback', @(s, e, hc, h) obj.mouseEnterButton(hControl, hS))
                set(jControl, 'MouseExitedCallback', @(s, e, hc, h) obj.mouseLeaveButton(hControl, hS))
                set(jControl, 'MousePressedCallback', @(s, e, hc, h) obj.mousePressButton(hControl, hS))
                set(jControl, 'MouseReleasedCallback', @(s, e, hc, h) obj.mouseReleaseButton(hControl, hS))
                %set(jControl, 'StateChangedCallback', @(s, e, hc, h) obj.valueChangeButton(hControl, hS))

                jControl = handle(jControl, 'CallbackProperties');
                
                %set(jControl, 'ComponentMovedCallback', @obj.onButtonResized)
                %set(jControl, 'ComponentResizedCallback', @obj.onButtonResized)
                set(jControl, 'AncestorResizedCallback', @obj.onButtonResized)
                set(jControl, 'AncestorMovedCallback', @obj.onButtonResized)

                %set(jControl, 'AncestorResizedCallback',@(s,e,msg)disp('resized'))
                %set(jControl, 'AncestorMovedCallback', @(s,e,msg)disp('moved'))
                %jControl.setIgnoreRepaint(true)

                
                if contains(hControl.Style, {'pushbutton'})
                    jControl.setCursor(java.awt.Cursor(java.awt.Cursor.HAND_CURSOR))
                end
            elseif contains(hControl.Style, {'popupmenu', 'checkbox'})
                jControl.setCursor(java.awt.Cursor(java.awt.Cursor.HAND_CURSOR))
            end
            
            if contains(hControl.Style, 'checkbox')
                set(jControl, 'StateChangedCallback', @(s, e, hc, h) obj.onValueChangedCheckbox(hControl, hS))
            end
            
            
            set(jControl, 'MouseClickedCallback', @(s, e, hc, h) obj.clicked(hControl, hS) )
            set(jControl, 'FocusGainedCallback', @(s, e, hc, h) obj.gainFocus(hControl, hS) )
            set(jControl, 'FocusLostCallback', @(s, e, hc, h) obj.loseFocus(hControl, hS) )

        end
        
        
        function gainFocus(obj, hControl, hS)
        % Change appeareance when uicontrol is in focus
            if ~isvalid(hControl); return; end
            
            switch hControl.Style
                case {'checkbox', 'edit', 'popupmenu'}
                    hS.hAmbience.Visible = 'on';
                    hS.hBorder.EdgeColor = obj.highlightColor;
                    
                case 'pushbutton'
                    
            end
            
            
            switch hControl.Style
                case 'checkbox'
                    if hControl.Value
                        hS.checkboxTick.Visible = 'on';
                    else
                        hS.checkboxTick.Visible = 'off';
                    end
                    drawnow limitrate
                
            end
        end
        
        
        function loseFocus(obj, hControl, hS)
            if ~isvalid(hControl); return; end
            
            hS.hAmbience.Visible = 'off';
            hS.hBorder.EdgeColor = obj.borderColor * 0.5;
        end
        

        function clickedPopupButton(~, popupHandle, hControl)
            
            isShown = popupHandle.isPopupVisible;
            
            if isShown
                popupHandle.setPopupVisible(false)
            else
                
                popupHandle.setPopupVisible(true)
            end
            
            drawnow
            
        end
        
        
        function deleteStyle(obj, ~, ~)
            
            if ~isempty(obj.hBox); delete(obj.hBox); end
            if ~isempty(obj.hOutline); delete(obj.hOutline); end
            if ~isempty(obj.hOther2); delete(obj.hOther2); end
        end
        
        
        
        function updatePopup(obj, hControl, hEditBox)
            
            hEditBox.String = hControl.String{hControl.Value};
            obj.keepTextWithinBox(hEditBox)
          
        end
        
        
        function mouseEnterPopupButton(obj, src)
            if isvalid(src)
                src.ForegroundColor = src.ForegroundColor * 1.5;
            end
        end
        
        
        function mouseLeavePopupButton(obj, src)
            if isvalid(src)
                src.ForegroundColor = src.ForegroundColor / 1.5;
            end
        end
        
        
        function mouseEnterButton(obj, hControl, hStyle)
            if isvalid(hControl)
                hStyle.hBorder.FaceAlpha = 0.25;
                hFig = ancestor(hStyle.hBorder, 'figure');
                hFig.Pointer = 'hand';


                switch hControl.Style
                    case 'togglebutton'
                        if hControl.Value
                            hStyle.hBorder.FaceAlpha = 0.4;
                        end

                    case 'pushbutton'
                        % Continue
                end
            end
        end
        
        
        function mouseLeaveButton(obj, hControl, hStyle)
            if isvalid(hControl)
                hStyle.hBorder.FaceAlpha = 0.1;
                hFig = ancestor(hStyle.hBorder, 'figure');
                hFig.Pointer = 'arrow';

                switch hControl.Style
                    case 'togglebutton'
                        if hControl.Value
                            hStyle.hBorder.FaceAlpha = 0.25;
                        end

                    case 'pushbutton'
                        % Continue
                end
            end
        end
        

        function mousePressButton(obj, hControl, hStyle)
            
            hStyle.hBorder.EdgeColor = obj.highlightColor;
            
            switch hControl.Style
                case 'togglebutton'
%                     if ~hControl.Value
%                         hStyle.hBorder.FaceColor = obj.highlightColor;
%                         hStyle.hBorder.FaceAlpha = 0.2;
%                     else
%                         hStyle.hBorder.FaceColor = obj.borderColor;
%                         hStyle.hBorder.FaceAlpha = 0.2;
%                     end
                        
                case 'pushbutton'
                    % Nothing more to be done.
            end
            
            
        end
        
        
        function mouseReleaseButton(obj, hControl, hStyle)
            hStyle.hBorder.EdgeColor = obj.borderColor * 0.5;
            
            switch hControl.Style
                case 'togglebutton'
                    if ~hControl.Value
                        hStyle.hBorder.FaceAlpha = 0.1;
                    end
                        
                case 'pushbutton'
                    % Nothing more to be done.
            end
            
            
        end
        
        
        function valueChangeButton(obj, hControl, hStyle)
            % Todo....
            
%             hControl.Value  % Toggle button press produce 5 value changes!
%             switch hControl.Style
%                 case 'togglebutton'
%                     if hControl.Value
%                         hStyle.hBorder.FaceColor = obj.highlightColor;
%                         hStyle.hBorder.FaceAlpha = 0.2;
%                     else
%                         hStyle.hBorder.FaceColor = obj.borderColor;
%                         hStyle.hBorder.FaceAlpha = 0;
%                     end
%                         
%                 case 'pushbutton'
%                     % Nothing more to be done.
%             end
            
        end
        
        
        function onValueChangedCheckbox(obj, hControl, hStyle)
            
            if hControl.Value
                hStyle.checkboxTick.Visible = 'on';
            else
                hStyle.checkboxTick.Visible = 'off';
            end
            
            drawnow limitrate
            
        end

    end
    
    
    
    methods (Static)
        
        function keepTextWithinBox(hTextbox)
            
            updated = false;
            while hTextbox.Extent(3) > hTextbox.Position(3) - 10
                hTextbox.String = hTextbox.String(1:end-1);
                updated = true;
                if isempty(hTextbox.String); break; end
            end

            if updated
                hTextbox.String = strcat(hTextbox.String, '...');
            end
            
        end
        
        function clicked(hControl, hS)
            
            if contains(hControl.Style, 'checkbox')
                
%                 if hControl.Value
%                     hS.checkboxTick.Visible = 'on';
%                 else
%                     hS.checkboxTick.Visible = 'off';
%                 end
%                 
%                 drawnow limitrate

            end
        end
        
        jhUic = findJavaComponents(hUic, hParent)
            
    end
        
        
    
end