function updateFunctionTemplate(functionFilePath, datalocation)
%updateFunctionTemplate Update a data location function with current data locations
%
%   updateFunctionTemplate(functionFilePath, datalocation) updates an
%   existing function file that contains switch-case blocks for different
%   data locations. This function will:
%       - Add case blocks for new data locations
%       - Remove case blocks for deleted data locations
%       - Rename case blocks for data locations whose names have changed
%
%   Input arguments:
%       functionFilePath - Full path to the function file to update
%       datalocation - Array of datalocation structures with fields:
%                      Name - The data location name
%                      Uuid - The unique identifier for the data location

    
    % Todo: Verify that this function works as expected

    functionStr = fileread(functionFilePath);
    updatedFunctionStr = functionStr;

    expression = 'case ''(?<name>.*?)'' %% <(?<uuid>.*?)>';
    extractedValues = regexp(functionStr, expression, 'names');

    % Create a map mapping extracted uuids and names for datalocations in
    % current function.
    datalocationMapOld = containers.Map();
    for i = 1:numel(extractedValues)
        datalocationMapOld(extractedValues(i).uuid) = extractedValues(i).name;
    end

    datalocationMapNew = containers.Map();
    for i = 1:numel(datalocation)
        datalocationMapNew(datalocation(i).Uuid) = datalocation(i).Name;
    end
    
    % Determine if data locations have been added or removed.
    addedDataLocations = setdiff(datalocationMapNew.keys, datalocationMapOld.keys);
    removedDataLocations = setdiff(datalocationMapOld.keys, datalocationMapNew.keys);
    
    % Extract all case blocks:
    expression = 'case[\s\S]*?(?=case|otherwise)';
    extractedBlocks = regexp(functionStr, expression, 'match');
    
    % Remove cases for removed data locations
    for i = 1:numel(extractedBlocks)
        for j = 1:numel(removedDataLocations)
            if contains(extractedBlocks{i}, removedDataLocations{j})
                updatedFunctionStr = strrep(updatedFunctionStr, extractedBlocks{i}, '');
                break; % Move to next block once we find a match
            end
        end
    end
    
    % Add cases for added data locations
    caseBlockTemplate = '        case ''%s'' %% <%s> [Do not remove]\n';

    newCaseBlocks = cell(1, numel(addedDataLocations));
    for i = 1:numel(addedDataLocations)
        dataLocationUuid = addedDataLocations{i};
        dataLocationName = datalocationMapNew(dataLocationUuid);
        newCaseBlocks{i} = sprintf(caseBlockTemplate, dataLocationName, dataLocationUuid);
    end
    
    newCaseBlocksStr = strjoin(newCaseBlocks, newline);
    
    % Insert new blocks before the otherwise statement
    if ~isempty(newCaseBlocksStr)
        otherwisePattern = '\s*otherwise';
        otherwiseMatch = regexp(updatedFunctionStr, otherwisePattern, 'match', 'once');
        if ~isempty(otherwiseMatch)
            updatedFunctionStr = regexprep(updatedFunctionStr, otherwisePattern, ...
                sprintf('%s\n%s', newCaseBlocksStr, otherwiseMatch), 'once');
        end
    end

    % Rename data location names in case blocks if data location name has changed
    % (UUID stays the same, but name is different)
    commonUuids = intersect(datalocationMapOld.keys, datalocationMapNew.keys);
    for i = 1:numel(commonUuids)
        uuid = commonUuids{i};
        oldName = datalocationMapOld(uuid);
        newName = datalocationMapNew(uuid);
        
        if ~strcmp(oldName, newName)
            % Find and replace the case statement for this UUID
            oldCasePattern = sprintf('case ''%s'' %%%% <%s>', oldName, uuid);
            newCaseStatement = sprintf('case ''%s'' %%%% <%s>', newName, uuid);
            updatedFunctionStr = strrep(updatedFunctionStr, oldCasePattern, newCaseStatement);
        end
    end

    utility.filewrite(functionFilePath, updatedFunctionStr)
end
