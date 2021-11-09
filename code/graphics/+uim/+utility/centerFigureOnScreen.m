function centerFigureOnScreen(hFig)

    
    % screenSize = get(0, 'ScreenSize');
    
    % For multiple monitors:
    MP = get(0, 'MonitorPosition');
    xPos = hFig.Position(1);
    yPos = hFig.Position(2);

    % Get screenSize for monitor where figure is located.
    for i = 1:size(MP, 1)
        if xPos > MP(i, 1) && xPos < sum(MP(i, [1,3]))
            if yPos > MP(i, 2) && yPos < sum(MP(i, [2,4]))
                screenNum = i;
                screenSize = MP(i,:);
                break
            end
        end
    end
        
    figPos = getpixelposition(hFig);
    figSize = figPos(3:4);
    
    margins = (screenSize(3:4) - figSize) ./ 2;
    figLocation = margins + screenSize(1:2);
            
    % Create the figure window
    setpixelposition(hFig, [figLocation figSize])

end