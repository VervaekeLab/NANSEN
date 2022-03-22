function [sessionArray, wasCanceled] = uiresolveDuplicateSessions(sessionArray, hFigure)
%uiresolveDuplicateSessions User interface to resolve duplicate sessions.    
    
    wasCanceled = true; % Initialize output state

    allSessionIDs = {sessionArray.sessionID};
    
    % Find duplicate sessions:
    [uniqueSessionIDs, ~, ind] = unique(allSessionIDs);
    occurance = histcounts( ind, max(ind) );
    duplicateSessionIDs = uniqueSessionIDs(occurance>1);
     
    isDuplicate = contains(allSessionIDs, duplicateSessionIDs);

    
    % Prepare prompt and options for user dialog
    question = ['Some sessions with identical session IDs were detected. ', ...
        'To resolve this issue, there are two options: 1) Exclude ', ...
        'duplicate sessions or 2) Resolve sessions manually and rerun ', ...
        'initialization'];
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