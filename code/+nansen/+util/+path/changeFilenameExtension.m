function newFilename = changeFilenameExtension(filename, newExtension)
%changeFilenameExtension Change the extension of a filename or file path
%
%   newFilename = changeFilenameExtension(filename, newExtension) returns
%   filename with its extension replaced by newExtension. A leading dot on
%   newExtension is optional.
%
%   Only the extension of the file name is changed. Folder names are left
%   untouched, including when they contain the old extension.
%
%   Example:
%       nansen.util.path.changeFilenameExtension('/data/my.mat.bak/x.mat', 'json')
%       % Returns '/data/my.mat.bak/x.json'
%
%   See also fileparts, fullfile

    arguments
        filename (1,:) char {mustBeNonempty}
        newExtension (1,:) char {mustBeNonempty}
    end

    if ~strncmp(newExtension, '.', 1)
        newExtension = ['.', newExtension];
    end

    % Split the name from the folder so that the replacement can not reach
    % into parent folder names.
    [folderPath, fileName] = fileparts(filename);
    newFilename = fullfile(folderPath, [fileName, newExtension]);
end
