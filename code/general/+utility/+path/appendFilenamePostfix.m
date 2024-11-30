function newFilename = appendFilenamePostfix(filename, postfix)
%APPENDFILENAMEPOSTFIX Append a postfix to a filename / filepath

    % Need to strip of the directories if this is a absolute/relative path
    [~, oldFilename] = fileparts( filename );
    newFilename = sprintf('%s_%s', oldFilename, postfix);
    newFilename = strrep(filename, oldFilename, newFilename);
end
