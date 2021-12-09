function [sessionFolderListOut] = matchSessionFolders(dataLocationModel, sessionFolderList)
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

    
    dataLocationTypes = {dataLocationModel.Data.Name};

    % Todo: make an exception for this...
    msg = 'The folderlist with sessionfolders does not match the data location model';
    assert(all(ismember(fieldnames(sessionFolderList), dataLocationTypes)), msg)
    
    % Initialize output
    initPaths = repmat({''}, 1, numel(dataLocationTypes));
    fieldValuePairs = cat(1, dataLocationTypes, initPaths);
    sessionFolderListOut = struct(fieldValuePairs{:});

    % Loop through data location types from the model
    for i = 1:numel(sessionFolderList.(dataLocationTypes{1}))
                
        pathStr = sessionFolderList.(dataLocationTypes{1}){i};
        sessionID = dataLocationModel.getSessionID(pathStr);

        sessionFolderListOut(i).(dataLocationTypes{1}) = pathStr;
        
        for j = 2:numel(dataLocationTypes)
            
            jSessionFolderList = sessionFolderList.(dataLocationTypes{j});
            isMatch = contains(jSessionFolderList, sessionID);

            if sum(isMatch) == 0
                pathStr = '';
            elseif sum(isMatch) == 1
                pathStr = jSessionFolderList{isMatch};
            else 
                warning('Multiple session folders matched for session %s. Selected first one', sessionID)
                pathStr = jSessionFolderList{find(isMatch, 1, 'first')};
            end
            
            sessionFolderListOut(i).(dataLocationTypes{j}) = pathStr;

        end
        
    end

    
    % Todo: Manually match folders which have multiple matches...
    
    
end
