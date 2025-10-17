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
            
            figureSize = getpref('NansenSetup', 'ProjectManagerWindowSize', obj.FigureSize);
            obj.Figure.Position(3:4) = figureSize;
            uim.utility.centerFigureOnScreen(obj.Figure)
            
            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end

        function resizeControlPanel(obj)
            obj.UIModule{1}.resizeComponents()
        end
    end

    methods (Access = protected)
        function onFigureClosed(obj, ~, ~)
            figureSize = obj.Figure.Position(3:4);
            setpref('NansenSetup', 'ProjectManagerWindowSize', figureSize)
            onFigureClosed@nansen.config.abstract.ConfigurationApp(obj)
        end
    end
end
