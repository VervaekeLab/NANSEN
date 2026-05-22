function [sessionArray, wasCanceled] = uiresolveDuplicateSessions(sessionArray, hFigure)
%uiresolveDuplicateSessions User interface to resolve duplicate sessions.

    allSessionIDs = string({sessionArray.sessionID});

    % Find duplicate sessions:
    [uniqueSessionIDs, ~, ind] = unique(allSessionIDs);
    occurrence = accumarray(ind(:), 1);
    duplicateSessionIDs = uniqueSessionIDs(occurrence>1);

    isDuplicate = ismember(allSessionIDs, duplicateSessionIDs);

    % Prepare prompt and options for user dialog
    question = ['Some sessions with identical session IDs were detected. ', ...
        'You can exclude every duplicate session from this initialization, ', ...
        'or inspect the duplicate folders manually. Manual resolution opens ', ...
        'a table where you can open the detected folders, rename or remove ', ...
        'folders outside NANSEN, and then rerun initialization.'];
    titleStr = 'Select Option';
    options = {'Exclude duplicates', 'Resolve manually'};
    default = 'Exclude duplicates';

    % Open a uiconfirm / questdlg to get answer from user
    if nargin == 2 && ~isempty(hFigure)
        answer = uiconfirm(hFigure, question, titleStr, ...
        'Icon', 'question', 'Options', options, ...
            'DefaultOption', find(strcmp(options, default)) );

    else
        answer = questdlg(question, titleStr, options{:}, default);
    end

    % Take appropriate action to user response

    switch answer
        case 'Exclude duplicates'
            sessionArray(isDuplicate) = [];
            wasCanceled = false;

        case 'Resolve manually'
            duplicateSessions = sessionArray(isDuplicate);
            nansen.manage.uiManualResolveDuplicateSessions(duplicateSessions)
            wasCanceled = true;
        otherwise
            wasCanceled = true;
    end
end
