function centerFigureOnScreen(hFig)
%centerFigureOnScreen Center figure on the monitor it is located

    screenSize = uim.utility.getCurrentScreenSize(hFig);
    
    figPos = getpixelposition(hFig);
    figSize = figPos(3:4);
    
    margins = (screenSize(3:4) - figSize) ./ 2;
    figLocation = margins + screenSize(1:2);
            
    % Create the figure window
    setpixelposition(hFig, [figLocation figSize])

end