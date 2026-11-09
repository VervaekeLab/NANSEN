function newFilename = appendToFilename(filename, suffix)
%appendToFilename Add text to the end of a file name, before its extension
%
%   newFilename = appendToFilename(filename, suffix) returns filename with
%   suffix inserted between the file name and its extension.
%
%   Only the name of the file is changed. Folder names are left untouched,
%   including when they contain the extension of the file.
%
%   Example:
%       nansen.util.path.appendToFilename('/data/my.mat.bak/x.mat', '_clean')
%       % Returns '/data/my.mat.bak/x_clean.mat'
%
%   See also nansen.util.path.changeFilenameExtension, fileparts, fullfile

    arguments
        filename (1,:) char {mustBeNonempty}
        suffix (1,:) char {mustBeNonempty}
    end

    [folderPath, fileName, extension] = fileparts(filename);
    newFilename = fullfile(folderPath, [fileName, suffix, extension]);
end
