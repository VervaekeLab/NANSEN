function S = getSessionMethodInfo(pathStr)
%GETSESSIONMETHODINFO Get info struct for session method
%
%   S = getSessionMethodInfo(pathStr)
%
%   S contains the following fields:
%         SessionMethodName
%         SessionMethodPathStr
%         SessionMethodPackageName
%         OptionsAlternatives

    S = struct();
    
    [~, fileName] = fileparts(pathStr);

    S.SessionMethodName = fileName;
    S.SessionMethodPathStr = pathStr;
    S.SessionMethodPackageName = utility.path.abspath2funcname(pathStr);

    optsManager = nansen.OptionsManager(S.SessionMethodPackageName);
    S.OptionsAlternatives = optsManager.AvailableOptionSets;

end
