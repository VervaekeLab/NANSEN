function openFolder(folderPath)
%openFolder Open a folder using the system's default method

    if isunix
        [status, ~] = unix(sprintf('open -a finder ''%s''', folderPath));
        if status
            fprintf('Folder was not found for given path ''%s'' \n', folderPath)
        end

    elseif ispc
        winopen(folderPath);
    end

end