function openFolder(folderPath)
%openFolder Open a folder using the system's (OS) default method
%
%   openFolder(folderPath)

    
    if ismac
        [status, ~] = unix(sprintf('open -a finder ''%s''', folderPath));
        
        if status
            % Todo: Throw exception.
            fprintf('Folder was not found for given path ''%s'' \n', folderPath)
        end
        
    elseif isunix % Todo: Test
        warning('Opening of folders on linux has not been tested.')
        unix(sprintf('nautilus ''%s''', folderPath));
        
    elseif ispc
        winopen(folderPath);
    end

    
end