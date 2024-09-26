function filewrite(fileName, textStr)

    folderPath = fileparts(fileName);
    
    if ~isempty(folderPath) && ~exist(folderPath, 'dir')
        mkdir(folderPath)
    end

    fid = fopen(fileName, 'w');
    fwrite(fid, textStr);
    fclose(fid);
end
