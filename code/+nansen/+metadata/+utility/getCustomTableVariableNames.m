function varNames = getCustomTableVariableNames(tableClassName)
%getCustomTableVariableNames Get names of custom tablevars for current project

    arguments
        tableClassName (1,1) string = 'session';
    end
    
    varNames = string.empty;

    % Get folder containing custom table variables from current project:
    project = nansen.getCurrentProject();
    if isempty(project)
        return
    else
        rootPathTarget = project.getTableVariableFolder();
    end

    fcnTargetPath = fullfile(rootPathTarget, sprintf('+%s', lower(tableClassName)));
    
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
