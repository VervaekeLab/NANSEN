classdef Preferences < uiw.model.Preferences
    %PREFERENCES Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        MinimumFigureSize (1,2) double = [800, 475];
        PreferredScreen = 1
        PreferredScreenPosition = nansen.Preferences.defaultPreferredScreenPos()
    end
    
    methods (Static)
        function pos = defaultPreferredScreenPos()
            
            screenSize = get(0, 'ScreenSize');
            
            defaultSize = [1180, 700];
            margins = (screenSize(3:4) - defaultSize) ./ 2;
            
            location = margins + screenSize(1:2);
            
            % Create the figure window
            pos = { [location defaultSize] };
            
        end
    end
end
