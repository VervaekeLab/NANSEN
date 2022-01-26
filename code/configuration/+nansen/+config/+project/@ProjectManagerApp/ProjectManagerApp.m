classdef ProjectManagerApp < nansen.config.project.ProjectManagerUI % applify.ModularApp & 
%ProjectManagerApp Create an app for the project manager
%
%   Todo: Program this using traditional gui figure for backwards
%   compatibility and more responsive figure.

    properties (Constant, Hidden)
        DEFAULT_THEME = nansen.theme.getThemeColors('light'); 
    end
    
    properties (Constant)
        AppName = 'Project Manager'
    end
    
    
    
    methods
        function obj = ProjectManagerApp()
            
            hFigure = uifigure;
            hFigure.Position(3:4) = [699,229]; 
            uim.utility.centerFigureOnScreen(hFigure)

            obj@nansen.config.project.ProjectManagerUI(hFigure);
            hFigure.Name = obj.AppName;

            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end
        
    end
    

end