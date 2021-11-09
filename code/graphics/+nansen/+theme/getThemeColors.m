function S = getThemeColors(themeName)
    
    switch themeName

        case 'dark-gray'
            
            %TODO...
            S.FigureBgColor = [0.05,0.05,0.05];
            S.FigureFgColor = [0.75,0.75,0.75];
            
%             S.PanelBgColor = [0.15,0.15,0.15];
%             S.PanelFgColor = [0.15,0.15,0.15];
            
            S.HeaderBgColor = [0.15,0.15,0.15];
            S.HeaderFgColor = [0.7,0.7,0.7];
            
            S.TableTheme = uim.style.tableDark;
            
        	S.FigureBackgroundColor = [0.06 0.06 0.06];
            S.AxesBackgroundColor = ones(1,3) .* 0.15;
            S.AxesForegroundColor = ones(1,3) .* 0.7;
            S.AxesGridAlpha = 0.5;
            S.MapAlpha = 0.8;
            S.ToolbarAlpha = 0.2;
            S.ToolbarDarkMode = 'on';
            
        case 'light'
            
            S.HeaderBgColor = [48,62,76]/255;
            S.HeaderMidColor = [74,86,99]/255;
            S.HeaderFgColor = [234,236,237]/255;
            
            S.FigureBgColor =  ones(1,3)*0.94;
            S.FigureFgColor = S.HeaderBgColor;
            
            
            S.TableTheme = uim.style.tableLight;
            
            S.FigureBackgroundColor = ones(1,3)*0.94;
            S.AxesBackgroundColor = [1, 1, 1];
            S.AxesForegroundColor = ones(1,3) .* 0.15;
            S.AxesGridAlpha = 0.15;
            S.MapAlpha = 1;
            S.ToolbarAlpha = 0.7;
            S.ToolbarDarkMode = 'off';
            S.SliderTextColor = ones(1,3) .* 0.15;
            
        case 'deepblue'
            S.HeaderBgColor = [48,62,76]/255;
            S.HeaderMidColor = [74,86,99]/255;
            S.HeaderFgColor = [234,236,237]/255;
            
            S.FigureBgColor = [246,248,252]/255;
            S.FigureFgColor = S.HeaderBgColor;
            
            S.MatlabBlue = [16,119,166]/255;
            S.ControlPanelsBgColor = [1,1,1];
            
            S.TableTheme = uim.style.tableLight;


        case 'green'
            S.HeaderBgColor = [48,76,62]/255;
            S.HeaderMidColor = [74,99,86]/255;
            S.HeaderFgColor = [234,237,236]/255;
            S.FigureBgColor = [246,252,248]/255;

            S.MatlabBlue = [16,119,166]/255;
            S.ControlPanelsBgColor = [1,1,1];
            
            S.TableTheme = uim.style.tableLight;


        case 'orange'

        case 'copper'

            %S.HeaderBgColor = [0.0392    0.0245    0.0156];
            %S.HeaderMidColor = [0.2598    0.1624    0.1034];
            
            S.HeaderBgColor = [0.1569    0.0980    0.0624];
            S.HeaderMidColor = [0.4804    0.3002    0.1912];
            S.HeaderFgColor =  [1.0000    0.7812    0.4975] ;
            S.FigureBgColor = [252, 246, 242]/255;

            S.MatlabBlue = [16,119,166]/255;
            S.ControlPanelsBgColor = [1,1,1];
            
        case 'dark-purple'
            
            S.FigureBgColor = [26,29,33] ./ 255;
            S.FigureFgColor = [209, 210, 211] ./ 255;

            S.HeaderBgColor = [0.15,0.15,0.15];
            S.HeaderFgColor = [0.7,0.7,0.7];
            
            S.TableTheme = uim.style.tableDark;
            
        	S.FigureBackgroundColor = S.FigureBgColor;
            S.AxesBackgroundColor = ones(1,3) .* 0.15;
            S.AxesForegroundColor = ones(1,3) .* 0.7;
            S.AxesGridAlpha = 0.5;
            S.MapAlpha = 0.8;
            S.ToolbarAlpha = 0.2;
            S.ToolbarDarkMode = 'on';
            
    end
    
end