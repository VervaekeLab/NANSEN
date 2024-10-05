classdef AddonManagerApp < nansen.config.abstract.ConfigurationApp
%@AddonManagerApp Create an app for the project manager
%
%   Todo: Program this using traditional gui figure for backwards
%   compatibility and more responsive figure.

    properties (Constant)
        AppName = 'Addon Manager'
    end

    methods
        
        function obj = AddonManagerApp(addonManager)

            import nansen.config.addons.AddonManagerUI
            
            obj.FigureSize = [699+40, 349];

            obj.createFigure()
            obj.Figure.Visible = 'on';

            cPanel = obj.createControlPanel(obj.Figure);
            obj.createLoadingPanel()

            %obj.setLayout()
            panelSize = obj.Figure.Position(3:4) - [40, 60];
            cPanel.Position = [20, 20, panelSize];
            
            obj.applyTheme()

            obj.UIModule{1} = AddonManagerUI(cPanel, addonManager);

            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end
    end
end
