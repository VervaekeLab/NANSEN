function pathStr = packagename2pathstr(packageName)
%PACKAGENAME2PATHSTR Convert package name to a local path string
%
%   pathStr = utility.path.packagename2pathstr(packageName) converts the
%   packagename to a pathstr. packageName can be a character vector or a
%   cell array of character vectors, and the output pathStr will have the
%   same type and size as the input.
%
%   EXAMPLE:
    
    convertToCell = false;
    if ~isa(packageName, 'cell')
        packageName = {packageName};
        convertToCell = true;
    end
    
    numPackages = numel(packageName);
    
    pathStr = cell(size(packageName));
    for i = 1:numPackages
        folderNames = strcat('+', strsplit(packageName{i}, '.'));
        pathStr{i} = fullfile(folderNames{:});
    end
    
    if convertToCell
        pathStr = pathStr{1};
    end
end
