classdef ProjectManagerApp < nansen.config.abstract.ConfigurationApp
%ProjectManagerApp Create an app for the project manager
%
%   Todo: Program this using traditional gui figure for backwards
%   compatibility and more responsive figure.

    properties (Constant)
        AppName = 'Project Manager'
    end

    methods
        
        function obj = ProjectManagerApp()
            
            obj.createFigure();
            obj.Figure.Visible = 'on';
            obj.AllowResize = 'on';
            obj.UIModule{1} = nansen.config.project.ProjectManagerUI(obj.Figure);
            %obj.Figure.Resize = 'on';
            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end

        function resizeControlPanel(obj)
            obj.UIModule{1}.resizeComponents()
        end
    end
end
