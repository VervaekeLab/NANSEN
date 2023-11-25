function openFile(pathName, mode)
%openFile Open a file using the system's (OS) default method
%
%   openFile(pathName) opens the file with the given path name using the
%       operating system's default way of opening files of given type.
%
%   openFile(pathName, mode) opens file using a specified mode (optional). 
%       Mode is either 'default' or 'text'. The text option is not
%       supported on windows.
    
    if nargin < 2; mode = 'default'; end
    validatestring(mode, {'default', 'text'}, 2)
    
    if isfile(pathName)

        if ismac || isunix

            switch mode
                case 'default'
                    [status, msg] = unix(sprintf('open ''%s''', pathName));
                case 'text'
                    [status, msg] = unix(sprintf('open -e ''%s''', pathName));
            end

            if status
                % Todo: Throw exception.
                error('Something went wrong: %s', msg)
            end

        elseif ispc
            switch mode
                case 'default'
                    winopen(pathName)
                case 'text'
                    error('Opening file as text on Windows platform is not implemented')
            end
        end

    elseif isfolder(pathName)
        error('Expected the given path to point to a file, points to a folder instead')
    else
        error('File does not exist (%s)', pathName)
    end
end