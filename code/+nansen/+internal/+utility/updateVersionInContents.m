function updateVersionInContents(newVersionNumber)
% updateVersionInContents - Update version number in the Contents.m file
%
%   Example:
%       updateVersionInContents('0.9.2')

    arguments
        newVersionNumber (1,1) string
    end

    pattern = '^\d+\.\d+\.\d+$|^\d+\.\d+\.\d+\.\d+$';
    assert( ~isempty( regexp(newVersionNumber, pattern, 'once')), ...
        'Invalid version number')

    % Update Contents.m
    contentsFilePath = fullfile(nansen.toolboxdir, 'Contents.m');
    str = fileread(contentsFilePath);
    lines = strsplit(str, newline);
    lines{2} = sprintf('%% Version %s %s', newVersionNumber, datetime("now", "Format", "dd-MM-uuuu"));
    str = strjoin(lines, newline);
    utility.filewrite(contentsFilePath, str);
end
