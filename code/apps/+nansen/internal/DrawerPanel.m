classdef DrawerPanel < handle
% DrawerPanel - (Not implemented yet) A sidepanel that can slide in and out

%   Todo:
%       [ ] Should the uipanel container be created internally or passed on
%           construction?
%       [ ] Add position property for where panel should be located when in
%           view
%       [ ] Configure button for bringing panel back into view
%       

    properties (SetAccess = private)
        UIPanel matlab.ui.container.Panel
        UIFigure matlab.ui.Figure
    end

    methods % Constructor
        function obj = DrawerPanel(uiPanel)
            obj.UIPanel = uiPanel;
            obj.UIFigure = ancestor(uiPanel, 'figure');
            obj.createPanelComponents()
        end
    end
    
    methods
        
        function createPanelComponents(obj)
        % createPanelComponents - Create panel components
        %
        %   This function creates a button for sliding the panel in and out
        %   of view.

            % Not implemented
            uim.UIComponentCanvas(obj.UIPanel);

            buttonSize = [21, 51];
            options = {'PositionMode', 'auto', 'SizeMode', 'manual', 'Size', buttonSize, ...
                'HorizontalTextAlignment', 'center', 'Icon', '>', ...
                'Location', 'west', 'Margin', [0, 15, 0, 0], ...
                'Callback', @(s,e) obj.hidePanel() };
            
            closeButton = uim.control.Button_(obj.UIPanel, options{:} ); %#ok<NASGU>
        end

        function showPanel(obj)
        % showPanel - Slide panel into view
            figPosPix = getpixelposition(obj.UIFigure);
           
            w = figPosPix(3);
            obj.UIPanel.Visible = 'on';
            for i = 25
                obj.UIPanel.Position(1) = w-10*i;
                pause(0.01)
            end
        end
        
        function hidePanel(obj)
        % hidePanel - Slide panel out of view
            figPosPix = getpixelposition(obj.UIFigure);
           
            w = figPosPix(3);
            % h = figPosPix(4);
            
            for i = 50:-1:1
                obj.UIPanel.Position(1) = w-10*i;
                pause(0.01)
            end
            obj.UIPanel.Visible = 'off';
        end
    end
end