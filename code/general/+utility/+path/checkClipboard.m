function pathArray = checkClipboard()
%checkClipboard Return cell array of pathstrings found on clipboard
%
%	pathArray = checkClipboard() returns a cell array of path
%	strings if those are present on the clipboard, otherwise return empty
%	str.

    % Check if there is anything on the clipboard
    str = clipboard('paste');

    if isunix && ~ismac
        
        str  = strsplit(str, 'file://');
        if numel(str) == 1
           warning('This might not work')
           str = str{1};
        elseif numel(str) == 2
           str = str{2};
           str = strrep(str, newline, '');
           
        else
            error('Not implemented')
        end
    end
    
    if ~isempty(str)
        
        % Remove " and ' from string.
        str = strrep(str, '"', '');
        str = strrep(str, '''', '');
        
        % Split by newline. String is multiline if many files are on the
        % clipboard
        str = strsplit(str, '\n');

        % Set pathArray to empty if string is not a file or folder
        if isfolder(str{1}) || isfile(str{1})
            pathArray = str;
        else
            pathArray = '';
        end
        
    else
        pathArray = '';
    end
end
