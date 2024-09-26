function newFilename = changeFilenameExtension(filename, newExtension)
%changeFilenameExtension Change the extension of a filename / filepath

    % Need to strip of the directories if this is a absolute/relative path
    [~, ~, oldExtension] = fileparts( filename );
    if ~strncmp(newExtension, '.', 1)
        newExtension = sprintf('.%s', newExtension);
    end

    newFilename = strrep(filename, oldExtension, newExtension);
end
