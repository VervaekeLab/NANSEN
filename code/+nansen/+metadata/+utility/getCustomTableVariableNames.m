function varNames = getCustomTableVariableNames()
    
    rootPathTarget = nansen.localpath('Custom Metatable Variable', 'current');
    fcnTargetPath = fullfile(rootPathTarget, '+session');
    
    currentPath = path;
    if ~contains(currentPath, fileparts(rootPathTarget))
        addpath(fileparts(rootPathTarget))
    end
    
    L = dir(fullfile(fcnTargetPath, '*.m'));
      
    varNames = strrep({L.name}, '.m', '');
    
end