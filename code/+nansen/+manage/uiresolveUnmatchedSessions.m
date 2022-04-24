function updatedFolderList = uiresolveUnmatchedSessions(...
                        matchedFolderList, unmatchedFolderList, hFigure)

                    
    % Prepare prompt and options for user dialog
    question = ['Some detected folders were not matched to any sessions. ', ...
        'To resolve this issue, there are two options: 1) Ignore ', ...
        'unmatched folders or 2) Match folders manually'];
    titleStr = 'Select Option';
    options = {'Ignore unmatched folders', 'Resolve manually'};
    default = 'Ignore unmatched folders';
    
    % Open a uiconfirm / questdlg to get answer from user
    if nargin >= 3 && ~isempty(hFigure)
        answer = uiconfirm(hFigure, question, titleStr, ...
        'Icon', 'question', 'Options', options, ...
            'DefaultOption', find(strcmp(options, default)) );
        
    else
        answer = questdlg(question, titleStr, options{:}, default);
    end
    
    % Take appropriate action to user response
    
    switch answer
        case 'Ignore unmatched folders'
            updatedFolderList = matchedFolderList;
            return
        case 'Resolve manually'
            % pass
        otherwise
            updatedFolderList = matchedFolderList;
            return

    end
    
    
    hDialog = nansen.dataio.session.FolderMatcherDialog(...
        matchedFolderList, unmatchedFolderList);
    
    uiwait(hDialog)
    
    updatedFolderList = hDialog.MatchedSessionFolderList;
    delete(hDialog)

end