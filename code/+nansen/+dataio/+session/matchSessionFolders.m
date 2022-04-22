function [sessionFolderListOut, sessionIDs, unmatchedSessionFolderList] = ...
    matchSessionFolders(dataLocationModel, sessionFolderList)
%MATCHSESSIONFOLDERS Match session folders across datalocations
%   This function should match sessionfolders across different
%   datalocations based on their sessionIDs. Therefore the key to this
%   function working is that the pathstring of the sessionfolders to match
%   contains the sessionID.
%
%       FOLDERLIST = matchSessionFolders(DATALOCATIONMODEL, FOLDERLIST)
%       returns a struct array (FOLDERLIST) containing one field for each
%       data location and nSession number of rows. The input FOLDERLIST is 
%       a struct with one field for each datalocation where the value for
%       each field is a cell array of sessionfolder paths.
%
%   See also nansen.dataio.session.listSessionFolders

    import nansen.dataio.session.matchFolderListWithSessionID
    
    dataLocationNames = {dataLocationModel.Data.Name};

    % Todo: make an exception for this...
    msg = 'The folderlist with sessionfolders does not match the data location model';
    assert(all(ismember(fieldnames(sessionFolderList), dataLocationNames)), msg)
    
    % Initialize output
    initPaths = repmat({''}, 1, numel(dataLocationNames));
    fieldValuePairs = cat(1, dataLocationNames, initPaths);
    sessionFolderListOut = struct(fieldValuePairs{:});
    blankList = sessionFolderListOut;
    
    numSessions = numel(sessionFolderList.(dataLocationNames{1}));
    sessionIDs = cell(numSessions, 1);

    sessionFolderListCell = struct2cell(sessionFolderList);

    matchCount = 0;
    
    % Loop through data location types from the model
    for i = 1:numel(sessionFolderList.(dataLocationNames{1}))
        
        wasMatched = false;
        
        referencePathStr = sessionFolderList.(dataLocationNames{1}){i};
        refrenceSessionID = dataLocationModel.getSessionID(referencePathStr);
        
        tmpList = blankList;
        
        for j = 2:numel(dataLocationNames)

            jSessionFolderList = sessionFolderListCell{j};
            isMatch = matchFolderListWithSessionID(jSessionFolderList, ...
                refrenceSessionID, dataLocationNames{j});

            if sum(isMatch) == 0
                matchedPathStr = '';
            elseif sum(isMatch) == 1
                matchIdx = find(isMatch);
                matchedPathStr = jSessionFolderList{isMatch};
            else 
                warning('Multiple session folders matched for session %s. Selected first one', refrenceSessionID)
                matchIdx = find(isMatch, 1, 'first');
                matchedPathStr = jSessionFolderList{matchIdx};
            end
            
            if ~isempty(matchedPathStr)
                wasMatched = true;
                
                % Clear path strings from the list when there is a match
                sessionFolderListCell{1}{i} = '';
                sessionFolderListCell{j}(matchIdx) = []; % Remove from list

                % Add paths to the temp matched list.
                tmpList.(dataLocationNames{1}) = referencePathStr;
                tmpList.(dataLocationNames{j}) = matchedPathStr;
            end
        end
        
        if wasMatched
            matchCount = matchCount + 1;
            sessionFolderListOut(matchCount) = tmpList;
            sessionIDs{matchCount} = refrenceSessionID;
        end
    end
    
    isPathEmpty = cellfun(@isempty, sessionFolderListCell{1});
    sessionFolderListCell{1}(isPathEmpty) = []; 
    unmatchedSessionFolderList = sessionFolderListCell;
    
    if all( cellfun(@isempty, unmatchedSessionFolderList) )
        unmatchedSessionFolderList = [];
    end

    if nargout == 1
        clear sessionIDs unmatchedSessionFolderList
    elseif nargout == 2
        clear unmatchedSessionFolderList
    end
        
end



