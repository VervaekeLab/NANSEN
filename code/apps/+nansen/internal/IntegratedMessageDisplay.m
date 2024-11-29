classdef IntegratedMessageDisplay < nansen.MessageDisplay
% IntegratedMessageDisplay - Not implemented yet
%
%   The idea of this class is to create a MessageDisplay which is embedded
%   in the NANSEN app window and uses uim.widget.messageBox for messages.
%
%   I think the main reason it is on hold is because it does not look very
%   nice to popup a panel in front of other components.

    properties (Access = private)
        MessagePanel matlab.ui.container.Panel
        MessageBox uim.widget.messageBox
    end

    methods
        function obj = IntegratedMessageDisplay(app)
            obj.App = app;
            obj.Figure = app.Figure;
        end

    end

    methods (Access = private)
        function createMessagePanel(obj)
            obj.MessagePanel = uipanel(obj.Figure, 'units', 'pixels');
            obj.MessagePanel.Position(3:4) = [400, 100];
            obj.MessagePanel.Visible = 'off';
            obj.MessagePanel.BorderType = 'line';
            referencePosition =  [1,1,obj.Figure.Position(3:4)];
            uim.utility.layout.centerObjectInRectangle(obj.MessagePanel, referencePosition)
            obj.MessageBox = uim.widget.messageBox(obj.MessagePanel);
        end
    end
    
end