function computerName = getComputerName(doHash)
%GETCOMPUTERNAME Return name of current computer/platform
%
%   computerName = GETCOMPUTERNAME()

    if nargin < 1
        doHash = false;
    end

    % Find computer name
    if ispc
        computerName = getenv('computername');
        computerName = char(getHostName(java.net.InetAddress.getLocalHost)); % Todo: is it better to use getenv?

    elseif ismac
        [~, macAdress] = system('ifconfig en0 | grep ether');
        ind0 = regexp(macAdress, 'ether', 'once', 'end');
        computerName = macAdress(2 + (ind0:ind0+16));
    elseif isunix
        [~, currentUsername] = system('whoami');
        currentUsername = strtrim(currentUsername);
        if strcmp(currentUsername, 'matlab') || strcmp(currentUsername, 'mluser')
            % Special case for matlab online
            computerName = 'matlab_online';
        else
            [status, computerName] = system('cat /etc/machine-id');
            if status ~= 0
                [~, computerName] = system('hostname');
            end
            computerName = strtrim(computerName);
        end
    end
    
    if doHash
        try
            Engine = java.security.MessageDigest.getInstance('MD5');
        catch ME  % Handle errors during initializing the engine:
           if ~usejava('jvm')
              error('Could not hash, Java Virtual Machine is needed.');
           end
           error('Something went wrong')
        end

        Engine.update(typecast(uint16(computerName(:)), 'uint8'));
        Hash = typecast(Engine.digest, 'uint8');
        computerName = sprintf('%.2x', double(Hash));
    end
end
