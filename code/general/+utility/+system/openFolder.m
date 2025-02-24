function openFolder(folderPath)
%openFolder Open a folder using the system's (OS) default method
%
%   openFolder(folderPath)
    
    if ismac
        if isfile(folderPath)
            [status, ~] = unix(sprintf('open -R ''%s''', folderPath));
        else
            [status, ~] = unix(sprintf('open -a Finder ''%s''', folderPath));
        end

        if status
            % Todo: Throw exception.
            fprintf('Folder was not found for given path ''%s'' \n', folderPath)
        end
        
    elseif isunix % Todo: Test
        warning('Opening of folders on linux has not been tested.')
        options = ["Nautilus", "Dolphin", "Thunar", "Nemo", "Caja"];
        for i = 1:numel(options)
            try
                cmdStr = sprintf("%s '%s'", options(i), folderPath);
                s = unix(cmdStr);
                if s == 0
                    return
                end
            catch
                % pass
            end
        end
        error('Failed to open folder in file explorer.')

    elseif ispc
        winopen(folderPath);
    end
end
