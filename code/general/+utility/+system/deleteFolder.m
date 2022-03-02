function deleteFolder(dirPath, varargin)
%deleteFolder Delete folder and folder contents
%
%   utility.system.deleteFolder(dirPath) deletes the folder at the given
%   directory path.
%   
%   utility.system.deleteFolder(dirPath, name, value) deletes the folder
%   using the name,value pair options
%
%   Parameters
%       moveToTrash : true (move folder to trash) | false (permanent delete)
%
%   Use this with care!!!


params = struct();
params.moveToTrash = true;
params = utility.parsenvpairs(params, [], varargin);


% set the state of recycle before deleting folder
if params.moveToTrash
    oldState = recycle('on');
else
    oldState = recycle('off');
end

% Make sure state of recycle is reset when function is finished.
cleanupObj = onCleanup(@(state) recycle(oldState));

% Loop through subfolders and files to delete
listing = dir(dirPath);

for i = 1:numel(listing)
    
    if strcmp(listing(i).name, '.') 
        continue
    elseif strcmp(listing(i).name, '..') 
        continue
    elseif listing(i).isdir
        utility.system.deleteFolder(fullfile(dirPath, listing(i).name))
    else
        delete(fullfile(dirPath, listing(i).name))
    end
end

% Remove directory if it still exists.
if exist(dirPath, 'dir')
    rmdir(dirPath)
end


