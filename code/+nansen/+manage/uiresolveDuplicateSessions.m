function [sessionArray, wasCanceled] = uiresolveDuplicateSessions(sessionArray, hFigure)
%uiresolveDuplicateSessions User interface to resolve duplicate sessions.

    allSessionIDs = string({sessionArray.sessionID});

    % Find duplicate sessions:
    [uniqueSessionIDs, ~, ind] = unique(allSessionIDs);
    occurrence = accumarray(ind(:), 1);
    duplicateSessionIDs = uniqueSessionIDs(occurrence>1);

    isDuplicate = ismember(allSessionIDs, duplicateSessionIDs);

    % Prepare prompt and options for user dialog
    keepFirstOption = 'Keep first';
    excludeAllOption = 'Exclude all';
    resolveManuallyOption = 'Resolve manually';

    question = { ...
        ['Some session folders give identical session IDs. If these folders ', ...
            'hold different sessions, change how the session ID is extracted ', ...
            'from the folder path and run this step again.'], ...
        '', ...
        sprintf(['"%s" keeps the first detected folder of each session ID ', ...
            'and lists the excluded folders in the command window. Choose ', ...
            'this if the folders with the same session ID are copies of the ', ...
            'same session.'], keepFirstOption), ...
        '', ...
        sprintf(['"%s" excludes every session that shares its session ID ', ...
            'with another session.'], excludeAllOption), ...
        '', ...
        sprintf(['"%s" opens a table where you can open the detected ', ...
            'folders, rename or remove folders outside NANSEN, and then run ', ...
            'this step again.'], resolveManuallyOption)};
    titleStr = 'Select Option';
    options = {keepFirstOption, excludeAllOption, resolveManuallyOption};
    default = excludeAllOption;

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
        case keepFirstOption
            [sessionArray, excludedSessionTable] = nansen.manage.excludeDuplicateSessions(...
                sessionArray, KeepFirst=true);
            displayExcludedSessions(excludedSessionTable)
            wasCanceled = false;

        case excludeAllOption
            sessionArray = nansen.manage.excludeDuplicateSessions(sessionArray);
            wasCanceled = false;

        case resolveManuallyOption
            duplicateSessions = sessionArray(isDuplicate);
            nansen.manage.uiManualResolveDuplicateSessions(duplicateSessions)
            wasCanceled = true;
        otherwise
            wasCanceled = true;
    end
end

function displayExcludedSessions(excludedSessionTable)
%displayExcludedSessions - Print the excluded session folders

    % detectNewSessions skips every folder whose session ID is already in
    % the session table, so the excluded folders are not reported again.
    fprintf('Kept the first folder of each duplicate session ID. Excluded %d session folders:\n', ...
        height(excludedSessionTable))
    disp(excludedSessionTable(:, ["SessionID", "DataLocation", "FolderPath"]))
end
