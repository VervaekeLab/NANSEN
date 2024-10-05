function filewrite(fileName, textStr)

    folderPath = fileparts(fileName);
    
    if ~isempty(folderPath) && ~isfolder(folderPath)
        mkdir(folderPath)
    end

    fid = fopen(fileName, 'w');
    fwrite(fid, textStr);
    fclose(fid);
end