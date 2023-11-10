function S = loadjson(jsonFilePath)
% loadjson - Load a struct from a json file
%
%   Syntax:
%       S = utility.io.loadjson(jsonFilePath) loads the struct S from the 
%       file specified by jsonFilePath.

% Note: Same as readstruct from json (introduced in R2023b)

    jsonStr = fileread(jsonFilePath);
    S = jsondecode(jsonStr);
end