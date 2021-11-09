function newPathStr = validatePathString(pathStr, currentPath)

    % Current path is empty is not supplied
    if nargin < 2; currentPath = ''; end
    
    if isequal(currentPath(end), filesep)
        currentPath = currentPath(1:end-1);
    end

    % Path equals current path if it is empty
    if isempty(pathStr); newPathStr = currentPath; return; end

    % check if (and go to parent folder)
    if contains(pathStr, '..')
        strmatch = strfind(pathStr, '..');
        for i = 1:numel(strmatch)
            [currentPath, ~, ~] = fileparts(currentPath);
        end

        newPathStr = fullfile(currentPath, pathStr(strmatch(end)+3:end));
        
    % Check if input is an absolute path
    elseif isequal(pathStr(1), '/') || isequal(pathStr(2), ':')
        if ismac && isequal(pathStr(1), '/')
            newPathStr = pathStr;
        elseif ispc && isequal(pathStr(2), ':')
            newPathStr = pathStr;
        else
            newPathStr = fullfile(currentPath, pathStr);
        end
        
    else
        newPathStr = fullfile(currentPath, pathStr);   
    end
    
end
        

