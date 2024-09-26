function varNames = getCustomTableVariableNames(tableClassName)
%getCustomTableVariableNames Get names of custom tablevars for current project

    if nargin < 1
        tableClassName = 'session';
    end
    
    % Get folder containing custom table variables from current project:
    rootPathTarget = nansen.ProjectManager().getCurrentProject().getTableVariableFolder();
    fcnTargetPath = fullfile(rootPathTarget, ['+', lower(tableClassName)]);
    
    % Add parent folder of package to path if it is not already there.
    currentPath = path;
    metaTableRootPath = fileparts(fileparts(rootPathTarget));
    if ~contains(currentPath, metaTableRootPath)
        addpath(metaTableRootPath)
    end
    
    % List contents of folder and get names of all .m files:
    L = dir(fullfile(fcnTargetPath, '*.m'));
    varNames = strrep({L.name}, '.m', '');
end
