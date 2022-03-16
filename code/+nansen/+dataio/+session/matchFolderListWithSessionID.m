function isMatch = matchFolderListWithSessionID(folderList, sessionID)
%MATCHFOLDERLISTWITHSESSIONID Summary of this function goes here
%   Detailed explanation goes here

    
    filePath = nansen.localpath('SessionMatchMaker');
    
    if ~isfile(filePath)
        isMatch = contains(folderList, sessionID);
        
    else
        matchMakerFcn = str2func( utility.path.abspath2funcname(filePath) );
        isMatch = matchMakerFcn(folderList, sessionID);
    end

end

