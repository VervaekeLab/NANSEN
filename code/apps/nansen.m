function hApp = nansen(userName, flags)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    arguments
        userName (1,1) string = ""
    end

    arguments (Repeating)
        flags (1,1) string
    end

    nansen.internal.introspection.assertSingleVersionOnPath('nansen')

    % Java classpath setup is a recurring pain. Verify that everything is
    % set up correctly before continuing.
    try
        nansen.internal.setup.verifyJavaDependencies()
    catch exception
        throwAsCaller(exception)
    end

    userName = char(userName);
    openApp = ~any(strcmp(string(flags), '-nogui'));

    try
        userSession = nansen.internal.user.NansenUserSession.instance(userName);

        if openApp
            userSession.assertProjectsAvailable()
            hApp = nansen.App(userSession);
        end
    catch ME
        hApp = [];
        switch ME.identifier
            case {'NANSEN:UserSession:UserProfileCreationAborted', ...
                    'NANSEN:UserSession:UnexpectedInput', ...
                    'NANSEN:UserSession:UserNameCaseMismatch'}
                % The user declined or mistyped an answer to a user session
                % question, or gave a profile name in the wrong case. Show
                % the message, not a stack trace.
                disp(ME.message)
            case 'Nansen:ProjectNotConfigured:MetatableMissing'
                disp(ME.message)
                disp('Run nansen.setup to configure project or nansen.ProjectManager to change current project.')
            case 'Nansen:NoProjectsAvailable'
                disp(ME.message)
            case 'MATLAB:class:InvalidSuperClass'
                if contains(ME.message, 'uiw.abstract.AppWindow')
                    error('The Widgets Toolbox is required for running Nansen. Please run nansen.setup to install external toolboxes.')
                end

            otherwise
                disp(getReport(ME, 'extended'))
        end
    end

    if nargout == 0
        clear hApp
    end
end
