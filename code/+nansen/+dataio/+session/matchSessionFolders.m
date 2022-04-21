function [sessionFolderListOut, sessionIDs] = matchSessionFolders(dataLocationModel, sessionFolderList)
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
    
    numSessions = numel(sessionFolderList.(dataLocationNames{1}));
    sessionIDs = cell(numSessions, 1);
    
    % Loop through data location types from the model
    for i = 1:numel(sessionFolderList.(dataLocationNames{1}))
                
        pathStr = sessionFolderList.(dataLocationNames{1}){i};
        sessionID = dataLocationModel.getSessionID(pathStr);

        sessionFolderListOut(i).(dataLocationNames{1}) = pathStr;
        sessionIDs{i} = sessionID;

        for j = 2:numel(dataLocationNames)
            
            jSessionFolderList = sessionFolderList.(dataLocationNames{j});
            
            isMatch = matchFolderListWithSessionID(jSessionFolderList, sessionID, dataLocationNames{j});

            if sum(isMatch) == 0
                pathStr = '';
            elseif sum(isMatch) == 1
                pathStr = jSessionFolderList{isMatch};
            else 
                warning('Multiple session folders matched for session %s. Selected first one', sessionID)
                pathStr = jSessionFolderList{find(isMatch, 1, 'first')};
            end
            
            sessionFolderListOut(i).(dataLocationNames{j}) = pathStr;

        end
        
    end

    if nargout == 1
        clear sessionIDs
    end
    
    % Todo: Manually match folders which have multiple matches...
    
end
