classdef ModuleManagerApp < nansen.config.abstract.ConfigurationApp
%ModuleManagerApp Create an app for the module manager
%
%   Todo: Program this using traditional gui figure for backwards
%   compatibility and more responsive figure.


    properties (Constant)
        AppName = 'Module Manager'
    end

    methods
        
        function obj = ModuleManagerApp()

            obj.FigureSize = [699+40, 349];

            obj.createFigure()
            obj.Figure.Visible = 'on';

            cPanel = obj.createControlPanel(obj.Figure);
            obj.createLoadingPanel()

            %obj.setLayout()
            panelSize = obj.Figure.Position(3:4) - [40, 60];
            cPanel.Position = [20, 20, panelSize];
            
            obj.applyTheme()

            obj.UIModule{1} = nansen.config.module.ModuleManagerUI(cPanel); 

            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end
        
    end

end
