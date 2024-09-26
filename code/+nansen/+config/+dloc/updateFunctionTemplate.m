function updateFunctionTemplate(functionFilePath, datalocation)

    % Note: Work in progress, not functional yet

    functionStr = fileread(functionFilePath);
    updatedFunctionStr = functionStr;

    expression = 'case ''(?<name>.*?)'' % <(?<uuid>.*?)>';
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
        if contains(extractedBlocks{i}, removedDataLocations)
            updatedFunctionStr = strrep(updatedFunctionStr, extractedBlocks{i}, '');
        end
    end
    
    % Add cases for added data locations
    caseBlockTemplate = '        case ''%s'' %% <%s> [Do not remove]\n';

    newCaseBlocks = cell(1, numel(datalocation));
    for i = 1:numel(addedDataLocations)
        dataLocationUuid = addedDataLocations{i};
        dataLocationName = datalocationMapNew(dataLocationUuid);
        newCaseBlocks{i} = sprintf(caseBlockTemplate, dataLocationName, dataLocationUuid);
    end
    
    newCaseBlocks = strjoin(caseBlocks, newline);
    
    % Todo: Insert new blocks before the otherwise statement

    % Todo: Rename data location names in case blocks id data location name
    % has changed.

    utility.filewrite(functionFilePath, updatedFunctionStr)
end
