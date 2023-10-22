function hApp = nansen(varargin)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    try
        userSession = nansen.internal.user.NansenUserSession.instance();
        hApp = nansen.App(userSession, varargin{:});
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