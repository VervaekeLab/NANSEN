function filePath = listFiles(filePathCellArray, filetype)

    if nargin < 2
        filetype = '';
    end

    L = [];
    
    for i = 1:numel(filePathCellArray)
        
        thisL = dir(filePathCellArray{i});
        thisL = thisL(~[thisL.isdir]);

        if isempty(L)
            L = thisL;
        else
            L = [L; thisL];
        end
    end

    filePath = fullfile({L.folder}, {L.name});
    keep = ~ strncmp({L.name}, '.', 1);
    filePath = filePath(keep);
    
    if ~isempty(filetype) % Filter by filetype...
        [~, ~, ext] = fileparts(filePath);
        keep = strcmp(ext, filetype);
        filePath = filePath(keep);
    end
    
    if isrow(filePath); filePath = filePath'; end
    

    
end