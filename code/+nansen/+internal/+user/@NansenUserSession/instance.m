function obj = instance(userName, mode, skipProjectCheck, options)
%instance Return a singleton instance of the NansenUserSession
%
%   Input arguments:
%       userName    - string, name of the user profile to open. Each
%           profile keeps its own preferences and projects in its own
%           preference directory. Defaults to the "default" profile.
%       mode        - char, 'check' (default) | 'force' | 'nocreate' | 'reset'
%       skipProjectCheck - logical (default = false)
%
%   Name-value arguments:
%       ConfirmNewUser - logical (default = true). Ask the user to confirm
%           before a user profile is created for a name that does not exist
%           yet. Set to false for programmatic use, e.g. in tests.

%   Note: to achieve a persistent singleton instance that survives a "clear
%   all" statement, the singleton instance is stored in the graphics root
%   object's appdata. Open question: Are there better ways to do
%   this?

    % - Set default arguments if none are given

    arguments
        userName (1,1) string = missing
        mode (1,1) string ...
            {mustBeMember(mode, ["check", "force", "nocreate", "reset"])} = "check"
        skipProjectCheck (1,1) logical = false
        options.ConfirmNewUser (1,1) logical = true
    end

    if ismissing(userName) || isempty(char(userName))
        userName = "default";
        changeUser = false;
    else
        changeUser = true;
    end

    SINGLETON_NAME = nansen.internal.user.NansenUserSession.SINGLETON_NAME;

    userName = string(userName); mode = string(mode);

    % Guard against a typo in the user name silently creating a new user
    % profile. This runs before an active session is closed, so declining
    % leaves the current session untouched.
    if options.ConfirmNewUser && ~any(mode == ["nocreate", "reset"])
        nansen.internal.user.NansenUserSession.confirmNewUserProfile(userName)
    end

    resetUserSessionInstance = false;
    userSessionObject = getappdata(0, SINGLETON_NAME);

    % - If user session exists, check that name is correct
    if ~isempty(userSessionObject) && isvalid(userSessionObject)
        if (userSessionObject.CurrentUserName ~= userName) & changeUser

            if mode == "force"
                warning('NANSEN:UserSession:UserSessionActive', ...
                    'Another user session is active and will be closed.')
                resetUserSessionInstance = true;

            elseif mode == "check"
                message = sprintf(...
                    "Another user session (user: '%s') is active.\n" + ...
                    "Do you want to end that session and start a new one?", ...
                    userSessionObject.CurrentUserName);

                if nansen.internal.user.NansenUserSession.askYesNo(message)
                    resetUserSessionInstance = true;
                else
                    disp('Returning current user session.')
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
        if isappdata(0, SINGLETON_NAME)
            rmappdata(0, SINGLETON_NAME)
        end
    end

    % - Construct the user session if singleton instance is not present
    if isempty(userSessionObject) && ~strcmp(mode, 'nocreate') && ~strcmp(mode, 'reset')
        userSessionObject = nansen.internal.user.NansenUserSession(userName, skipProjectCheck);
        setappdata(0, SINGLETON_NAME, userSessionObject)

        % Check if user's data need to be updated due to changes in the
        % code base. Important that this is done after the singleton is created.
        userSessionObject.runPostConstructionUpdateActions()
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
