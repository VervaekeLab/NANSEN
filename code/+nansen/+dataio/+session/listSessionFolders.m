function sessionFolders = listSessionFolders(dataLocationModel, dataLocationName, varargin)
%listSessionFolders Lists session folders in a data location.
%
%   Inputs:
%       dataLocationModel       :
%       dataLocationName (char) : Name of data location type.

    % Todo: 
    %   [ ] Generalize to list subfolders for each entry in folder
    %       structure. Did I mean each entry in datalocName or each subfolder
    %       level in SubfolderStructure?
    %
    %   [ ] Add as method in data location model.
    
    
    % Set value of idx if it was not given
    if nargin < 2 || isempty(dataLocationName)
        dataLocationName = 'all';
    end
    
    
    allDataLocationNames = {dataLocationModel.Data.Name};
    
    % Get indicies for datalocation items to list session folders from
    if ischar(dataLocationName) && strcmp(dataLocationName, 'all')
        ind = 1:numel(dataLocationModel.Data);
    elseif ischar(dataLocationName) || iscell(dataLocationName)
        ind = find( strcmp(allDataLocationNames, dataLocationName) );
    elseif isnumeric(dataLocationName)
        ind = dataLocationName;
    else
        error('Invalid input for listSessionFolder, please see help')
    end
    
    sessionFolders = struct;
    
    for i = ind

        %rootPath = dataLocationModel.Data(i).RootPath{1};
        rootPath = {dataLocationModel.Data(i).RootPath.Value};
        
        S = dataLocationModel.Data(i).SubfolderStructure;

%         if ~isfolder(rootPath)
%             error('Root directory does not exist')
%         end
        
        if isequal(rootPath, 'HDD')
            %Todo: Find all mounted volumes and loop through.
            error('Not implemented yet')
        end

        for j = 1:numel(S)
            expression = S(j).Expression;
            ignoreList = S(j).IgnoreList;
            [rootPath, ~] = utility.path.listSubDir(rootPath, expression, ignoreList, 1, 1);
        end
                
        fieldName = dataLocationModel.Data(i).Name;
        sessionFolders.(fieldName) = rootPath;
        
    end
    
    % Todo:
    % Match folders from different data locations?
    % Match based on what?
    

    
    
    
% %     % This is a stupid idea because session folders from two different
% %     % types do not necessarily match!
% %     
% %     % Convert session folders to 
% %     types = {dataLocationModel.Data(ind).Name};
% %     sessionFolders = cat(1, sessionFolders{:});
% %     
% %     if numel(ind) == 1
% %         sessionFolders = struct(types{1}, sessionFolders);
% %     else
% %         % Todo: Test this:
% %         sessionFolders = cell2struct(sessionFolders', types, 1);
% %     end
% % % %     % Output as cell array if only one data type was requested.
% % % %     if numel(ind) == 1
% % % %         sessionFolders = sessionFolders.(iDataType);
% % % %     end
    
end