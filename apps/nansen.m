function hApp = nansen(varargin)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
    
    try
        hApp = nansen.App(varargin{:});
    catch ME
        hApp = [];
        switch ME.identifier
            case 'Nansen:ProjectNotConfigured:MetatableMissing'
                disp(ME.message)
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