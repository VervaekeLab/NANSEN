function obj = instance(userName, mode, skipProjectCheck)
%instance Return a singleton instance of the NansenUserSession
%
%   Input arguments:
%       userName    - Not supported yet
%       mode        -  char, 'check' (default) | 'force' | 'nocreate' | 'reset'
%       skipProjectCheck - logical (default = false)

%   Note: to achieve persistent singleton instance that survives a clear
%   all statement, the singleton instance is stored in the graphics root
%   object's UserData property. Open question: Are there better ways to do
%   this?

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

    if nargin < 3 || isempty(skipProjectCheck)
        skipProjectCheck = false;
    end

    userName = string(userName); mode = string(mode);

    %persistent userSessionObject % Singleton instance
    userSessionObject = [];
    resetUserSessionInstance = false;

    rootUserData = get(0, 'UserData');
    if isstruct(rootUserData)
        if isfield(rootUserData, 'SingletonInstances')
            if isfield(rootUserData.SingletonInstances, 'NansenUserSession')
                userSessionObject = rootUserData.SingletonInstances.NansenUserSession;
            end
        end
    end
    
    % - If user session exists, check that name is correct
    if ~isempty(userSessionObject) && isvalid(userSessionObject)
        if (userSessionObject.CurrentUserName ~= userName) & changeUser

            if mode == "force"
                warning('NANSEN:UserSession:UserSessionActive', ...
                    'Another user session is active and will be closed.')
                resetUserSessionInstance = true;
                %delete(userSessionObject)
                %userSessionObject = [];

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
                        resetUserSessionInstance = true;
                        %delete(userSessionObject)
                        %userSessionObject = [];
                    case 'n'
                        disp('Returning current user session.')
                    otherwise
                        error('Unexpected input "%s". Expected "y" or "n"', answer)
                end
            end
        end
    else
        % Pass
    end
    
    if strcmp(mode, 'reset')
        resetUserSessionInstance = true;
    end

    if resetUserSessionInstance
        delete(userSessionObject)        
        userSessionObject = [];
        rootUserData.SingletonInstances.NansenUserSession = [];
        set(0, 'UserData', rootUserData)
    end

    % - Construct the user session if singleton instance is not present
    if isempty(userSessionObject) && ~strcmp(mode, 'nocreate') && ~strcmp(mode, 'reset')
        userSessionObject = nansen.internal.user.NansenUserSession(userName, skipProjectCheck);
        
        rootUserData.SingletonInstances.NansenUserSession = userSessionObject;
        set(0, 'UserData', rootUserData)
    end

    % % % For development/debugging:
    if nansen.internal.user.NansenUserSession.LOG_UUID
        if isempty(userSessionObject)
            fprintf('No user session active.\n')
        else
            fprintf('User session (%s).\n', userSessionObject.SessionUUID)
        end
    end

    % - Return the instance
    obj = userSessionObject;
end