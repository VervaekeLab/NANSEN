function isMatch = matchFolderListWithSessionID(folderList, sessionID, dataLocationName)
%MATCHFOLDERLISTWITHSESSIONID Summary of this function goes here
%   Detailed explanation goes here

    % Question: Should this be a template function which is added to all projects?
    
    fileName = 'matchFolderListWithSessionID.m';

    project = nansen.getCurrentProject();
    filePath = fullfile( project.getModuleFolder(), fileName);
    
    if ~isfile(filePath)
        isMatch = contains(folderList, sessionID);
    else
        matchMakerFcn = str2func( utility.path.abspath2funcname(filePath) );
        isMatch = matchMakerFcn(folderList, sessionID, dataLocationName);
    end
end
