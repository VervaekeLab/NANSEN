function savejson(jsonFilePath, S)
% savejson - Save a struct to json
%
%   Syntax:
%       utility.io.savejson(jsonFilePath, S) saves the struct S to the file
%       specified by jsonFilePath.

% Note: Same as writestruct as json (introduced in R2023b)

    jsonStr = jsonencode(S, 'PrettyPrint', true);
    
    % Update json file properties. Replace the x_ (matlab encoded) with _
    jsonStr = strrep(jsonStr, '"x_type":', '"_type":');
    jsonStr = strrep(jsonStr, '"x_description":', '"_description":');
    jsonStr = strrep(jsonStr, '"x_version":', '"_version":');

    utility.filewrite(jsonFilePath, jsonStr)
end
