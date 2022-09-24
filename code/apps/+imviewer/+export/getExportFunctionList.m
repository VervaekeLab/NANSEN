function fcnList = getExportFunctionList()
% Summary of this function goes here
    
    % Todo: Add watch folders...

    [currentFolder, currentName] = fileparts(mfilename('fullpath'));
    L = dir( fullfile(currentFolder, '*.m') );
    
    discard = strncmp({L.name}, '.', 1);
    L(discard) = [];
    
    [~, fcnList] = fileparts( {L.name} );
    
    fcnList(strcmp(fcnList, currentName)) = [];
    
end

