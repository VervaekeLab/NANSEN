function informUser(infoID, mode)
    %informUser - Use popup dialog to inform user about things.
    %
    % Input argument
    %   infoID : An ID for which info message to show
    %
    %   mode : 'default', 'show', 'reset', 
    %     - default : show message if user did not previously select to not 
    %                 show message again 
    %     - show    : show message independent of user preference
    %     - reset   : reset the user selection of whether to show message
    %                 or not

    if nargin < 2; mode = "default"; end
     
    persistent shownThisUserSession % Dictionary for storing whether a message has been shown during the current usersession
    if isempty(shownThisUserSession); shownThisUserSession = containers.Map(); end

    preferenceGroup = 'Nansen_Roimanager_Info';
    
    if strcmp(mode, "default")
        if isKey(shownThisUserSession, infoID)
            return
        end
    end

    switch infoID
        case 'AdjustAutodetectionArea'
            preferenceName = 'HowToAdjustAutodetectionArea';
            dialogMessage = {...
                'To adjust the active area used for autodetection of rois, use ''alt'' + mousescroll.', ...
                'The Crosshairs should resize to indicate the size of the active area' };
            
    end

    dialogTitle = 'Info';

    switch mode
        case "reset"
            setpref(preferenceGroup, preferenceName, 'ask');

        case "default"
            [pval, tf] = uigetpref(preferenceGroup, preferenceName, ...
                dialogTitle, dialogMessage, {'Ok'});
            shownThisUserSession(infoID) = true;
            
        case "show"
            msgbox(dialogMessage, dialogTitle)
    end
end
