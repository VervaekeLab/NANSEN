function obj = instance(userName, mode)
%instance Return a singleton instance of the NansenUserSession
%
%   Input arguments:
%
%       userName    - Not supported yet
%   
%       mode        -  char, 'check' (default) | 'force' | 'nocreate'

    % - Set default arguments if none are given
    if nargin < 1 || isempty(userName)
        userName = "default";
        changeUser = false;
    else
        changeUser = true;
    end

    if nargin < 2 || isempty(mode)
        mode = "check";
    end

    userName = string(userName); mode = string(mode);
    
    obj = [];

    persistent userSessionObject % Singleton instance
    
    % - If user session exists, check that name is correct
    if ~isempty(userSessionObject) && isvalid(userSessionObject)
        if (userSessionObject.CurrentUserName ~= userName) & changeUser

            if mode == "force"
                warning('NANSEN:UserSession:UserSessionActive', ...
                    'Another user session is active and will be closed.')
                delete(userSessionObject)
                userSessionObject = [];

            elseif mode == "check"
                message = sprintf(...
                    "Another user session (user: '%s') is active.\n" + ...
                    "Do you want to end that session and create " + ...
                    "a new one?\n(y/n):", ...
                    userSessionObject.CurrentUserName);
                
                fprintf(newline)
                answer = input(message, 's');
                fprintf(newline)

                switch answer
                    case 'y'
                        delete(userSessionObject)
                        userSessionObject = [];
                    case 'n'
                        disp('Returning current user session.')
                    otherwise
                        error('Unexpected input "%s". Expected "y" or "n"', answer)
                end
            end
        end
    end

    % - Construct the user session if singleton instance is not present
    if isempty(userSessionObject) && ~strcmp(mode, 'nocreate')
        userSessionObject = nansen.internal.user.NansenUserSession(userName);
    end

    % - Return the instance
    obj = userSessionObject;
end