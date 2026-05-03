function folderPath = stripTrailingFilesep(folderPath)
%stripTrailingFilesep Remove trailing file separators from path string(s).
%
%   folderPath = stripTrailingFilesep(folderPath) removes any trailing
%   file separator characters from each element of folderPath. Accepts
%   both char and string; always returns a string array of the same size.

    folderPath = string(folderPath);
    for i = 1:numel(folderPath)
        while strlength(folderPath(i)) > 1 && endsWith(folderPath(i), filesep)
            folderPath(i) = extractBefore(folderPath(i), strlength(folderPath(i)));
        end
    end
end
