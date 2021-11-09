function [screenSize, screenNumber] = getCurrentScreenSize(hFig)
%GETCURRENTSCREENSIZE Summary of this function goes here

    MP = get(0, 'MonitorPosition');
    xPos = hFig.Position(1);
    yPos = hFig.Position(2);

    % Get screenSize for monitor where figure is located.
    for i = 1:size(MP, 1)
        if xPos > MP(i, 1) && xPos < sum(MP(i, [1,3]))
            if yPos > MP(i, 2) && yPos < sum(MP(i, [2,4]))
                screenNumber = i;
                screenSize = MP(i,:);
                break
            end
        end
    end

    
    if nargout == 1
        clear screenNumber
    end


end

