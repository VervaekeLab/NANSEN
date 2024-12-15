function hApp = nansen(userName, flags)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    arguments
        userName (1,1) string = ""
    end
    
    arguments (Repeating)
        flags (1,1) string
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
