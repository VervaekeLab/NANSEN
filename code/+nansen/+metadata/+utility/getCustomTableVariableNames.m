function varNames = getCustomTableVariableNames()
%getCustomTableVariableNames Get names of custom tablevars for current project

    rootPathTarget = nansen.localpath('Custom Metatable Variable', 'current');
    fcnTargetPath = fullfile(rootPathTarget, '+session');
    
    currentPath = path;
    if ~contains(currentPath, fileparts(rootPathTarget))
        addpath(fileparts(rootPathTarget))
    end
    
    L = dir(fullfile(fcnTargetPath, '*.m'));
      
    varNames = strrep({L.name}, '.m', '');
    
end