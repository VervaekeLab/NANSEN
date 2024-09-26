function sessionFolders = listSessionFolders(dataLocationModel, dataLocationName, varargin)
%listSessionFolders Lists session folders in a data location.
%
%   Syntax:
%       sessionFolders = listSessionFolders(dataLocationModel) returns a
%           struct with session folders for all available data locations
%
%       sessionFolders = listSessionFolders(dataLocationModel, dataLocationName)
%           returns a struct with session folders for data locations
%           specified by the dataLocationName
%
%   Inputs:
%       dataLocationModel (object) : DataLocationModel instance
%       dataLocationName (char)    : Name of data location type. This can
%           be a character vector or a cell array of character vectors. Use
%           this option to list session folders for a subset of Data
%           Locations. The default value is 'all' for which all available
%           data locations are used.
%
%   Outputs:
%       sessionFolders (struct) : A struct where each field is the name of
%       a Data Location and each value is a cell array of folderpaths
%       of session folders of the respective Data Location

    % Todo:
    %   [ ] Add as method in data location model.
    %   [ ] Check if folder(s) specified by rootPath exist before calling listSubDir?
    
    % Set value of idx if it was not given
    if nargin < 2 || isempty(dataLocationName)
        dataLocationName = 'all';
    end
    
    allDataLocationNames = {dataLocationModel.Data.Name};
    
    % Get indices for datalocation items to list session folders for
    if ischar(dataLocationName) && strcmp(dataLocationName, 'all')
        ind = 1:numel(dataLocationModel.Data);
    elseif ischar(dataLocationName) || iscell(dataLocationName)
        ind = find( strcmp(allDataLocationNames, dataLocationName) );
    elseif isnumeric(dataLocationName)
        ind = dataLocationName;
    else
        error('Invalid input for listSessionFolder, please see help')
    end
    
    sessionFolders = struct; % Initialize output
    
    for i = ind
        rootPath = {dataLocationModel.Data(i).RootPath.Value};
        S = dataLocationModel.Data(i).SubfolderStructure;

        for j = 1:numel(S) % Loop through each subfolder level
            expression = S(j).Expression;
            ignoreList = S(j).IgnoreList;
            [rootPath, ~] = utility.path.listSubDir(rootPath, expression, ignoreList, 1);
        end
                
        fieldName = dataLocationModel.Data(i).Name;
        sessionFolders.(fieldName) = rootPath;
    end
end
