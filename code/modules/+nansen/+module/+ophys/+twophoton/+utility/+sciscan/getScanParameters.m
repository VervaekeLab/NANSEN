function parameterStruct = getScanParameters(dataFolderPath, parameterList)
%getScanParameters Get scan parameters from sciscan recording
%
%   parameterStruct = getScanParameters(dataFolderPath, parameterList)
%   returns a struct of parameters for the recording located in
%   dataFolderPath for each of the parameters in the parameter list.
%   Parameter list is a character vector or a cell array of character
%   vectors with the name(s) of each paramter to get. The parameter names
%   must mach the names from the ini-file.
%
%   parameterStruct contains the names and value of each parameter. The
%   name is modified from the name of the ini variable name in the
%   following way: 
%       1) . are removed
%       2) All letters are lower case


import nansen.module.ophys.twophoton.utility.sciscan.readinivar

ini_file = dir(fullfile(dataFolderPath, '20*.ini'));
inifilepath = fullfile(dataFolderPath, ini_file(1).name);
inistring = fileread(inifilepath);

if ~isa(parameterList, 'cell')
    parameterList = {parameterList};
end

for i = 1:numel(parameterList)
    varname = parameterList{i};
    matlabname = lower(varname);
    matlabname = strrep(matlabname, '.', '');
    parameterStruct.(matlabname) = readinivar(inistring, varname);
end

end