function [sessionFolderListOut, sessionIDs, unmatchedSessionFolderList] = ...
    matchSessionFolders(dataLocationModel, sessionFolderList)
%MATCHSESSIONFOLDERS Match session folders across datalocations
%   This function should match sessionfolders across different
%   datalocations based on their sessionIDs. Therefore the key to this
%   function working is that the pathstring of the sessionfolders to match
%   contains the sessionID.
%
%   Syntax:
%       FOLDERLIST = matchSessionFolders(DATALOCATIONMODEL, FOLDERLIST)
%       returns a struct array (FOLDERLIST) containing one field for each
%       data location and nSession number of rows. The input FOLDERLIST is
%       a struct with one field for each datalocation where the value for
%       each field is a cell array of sessionfolder paths.
%
%   Input:
%       dataLocationModel : A data location model instance
%
%       sessionFolderList : A struct containing lists of session folders.
%                           Each field of the struct corresponds to a data
%                           location and each value will be a cell array of
%                           path strings (char) representing session
%                           folders in the corresponding data location
%
%   Output:
%       sessionFolderListOut : A struct array (1xN) where N is the number
%                              of sessions detected (detected session IDs)
%                              and each field represents a data location.
%                              Each element in the struct will represent a
%                              set of matched session folders across data
%                              locations.
%       sessionIDs           : A cell array of session IDs where each
%                              element corresponds to the element of the
%                              sessionFolderListOut.
%       unmatchedSessionFolderList : A cell array arranged in the same way
%                              as sessionFolderList (input) where each
%                              value is a set of session folders that were
%                              not matched to any other.
%
%   See also nansen.dataio.session.listSessionFolders

    % Todo:
    %   [ ] Test and potentially deal with data locations / session folders
    %   with multiple matches per session id.
    
    dataLocationNames = {dataLocationModel.Data.Name};

    % Todo: make an exception for this...
    msg = 'The folderlist with sessionfolders does not match the data location model';
    assert(all(ismember(fieldnames(sessionFolderList), dataLocationNames)), msg)
    
    % Initialize output
    initPaths = repmat({''}, 1, numel(dataLocationNames));
    fieldValuePairs = cat(1, dataLocationNames, initPaths);
    blankList = struct(fieldValuePairs{:});
    
    %numSessions = numel(sessionFolderList.(dataLocationNames{1}));
    %sessionIDs = cell(numSessions, 1); % Note: Not populated

    sessionIds = getSessionIDsForPaths(dataLocationModel, sessionFolderList); % Local function
    uniqueSessionIds = getUniqueSessionIds(sessionIds);
    sessionIDs = uniqueSessionIds;

    % Todo: check for empty ids?

    S = repmat(blankList, 1, numel(uniqueSessionIds));
    
    % Check for matching session IDs in each data location
    for j = 1:numel(dataLocationNames)
        currentName = dataLocationNames{j};
        [~, iA, iC] = intersect(uniqueSessionIds, sessionIds.(currentName), 'stable');
        [S(iA).(currentName)] = deal(sessionFolderList.(currentName){iC});
    end

    % Check if any folders contain session ID. This will apply only if a
    % session folder for a specific data location was not assigned in the
    % previous step
    for k = 1:numel(uniqueSessionIds)
        currentSessionId = uniqueSessionIds{k};
        for j = 1:numel(dataLocationNames)
            currentName = dataLocationNames{j};
            if isempty(S(k).(currentName))
                isMatch = contains( sessionFolderList.(currentName), currentSessionId);
                if any(isMatch)
                    if sum(isMatch) == 1
                        S(k).(currentName) = sessionFolderList.(currentName){isMatch};
                    else
                        warning('Multiple session folders matched for session id %s', currentSessionId)
                    end
                end
            end
        end
    end

    sessionFolderListOut = S;

    % Create a cell array of all folders that were not paired/matched with
    % any other:
    
    for i = 1:numel(sessionFolderListOut)
        numMatch = sum( structfun(@(v) ~isempty(v), sessionFolderListOut(i)) );
        if numMatch > 1
            for j = 1:numel(dataLocationNames)
                thisName = dataLocationNames{j};
                thisPath = sessionFolderListOut(i).(thisName);

                isMatch = strcmp(sessionFolderList.(thisName), thisPath);
                if any(isMatch)
                    sessionFolderList.(thisName)(isMatch) = [];
                end
            end
        end
    end
    unmatchedSessionFolderList = struct2cell(sessionFolderList);

    if nargout == 1
        clear sessionIDs unmatchedSessionFolderList
    elseif nargout == 2
        clear unmatchedSessionFolderList
    end
end

function sessionIds = getSessionIDsForPaths(dataLocationModel, sessionFolderList)
% getSessionIDs - Get session ids for a list of filepaths
    
    dataLocationNames = {dataLocationModel.Data.Name};

    sessionIds = struct;

    % Go through each data location:
    for iDataLocation = 1:numel(dataLocationNames)
        currentDataLocationName = dataLocationNames{iDataLocation};
        currentDataLocationIdx = dataLocationModel.getItemIndex(currentDataLocationName);
        
        pathStrList = sessionFolderList.(currentDataLocationName);
        sessionIDList = cell(size(pathStrList));
        
        % Try to extract sessionID
        for jPath = 1:numel(pathStrList)
            sessionIDList{jPath} = dataLocationModel.getSessionID(...
                pathStrList{jPath}, currentDataLocationIdx);
        end
        sessionIds.(currentDataLocationName) = sessionIDList;
    end
end

function uniqueSessionIds = getUniqueSessionIds(sessionIds)
    
    % Ensure all cells are row vectors
    dlNames = fieldnames(sessionIds);
    for i = 1:numel(dlNames)
        if ~isrow(sessionIds.(dlNames{i}))
            sessionIds.(dlNames{i}) = sessionIds.(dlNames{i})';
        end
    end
    sessionIds = struct2cell(sessionIds);
    uniqueSessionIds = unique( [sessionIds{:}] );
    uniqueSessionIds(strcmp(uniqueSessionIds, ''))=[];
end
