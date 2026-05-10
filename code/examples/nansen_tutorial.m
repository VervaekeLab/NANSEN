function nansen_tutorial(tutorial) 
    
    arguments
        tutorial nansen.app.tutorial.enum.Tutorial {mustBeScalarOrEmpty} = nansen.app.tutorial.enum.Tutorial.empty
    end
    
    % Install core nansen dependencies if missing
    deps = nansen.internal.dependencies.resolveRequirements('MissingOnly', true);
    if ~isempty(deps)
        nansen.install()
    else
        nansen.internal.setup.verifyInstallation()
    end
    
    try
        nansen.App.getInstance();
        answer = questdlg('NANSEN is already open. Quit NANSEN and run tutorial?', 'Quit NANSEN?', 'Yes', 'No', 'Cancel', 'Yes');
        switch answer
            case 'Yes'
                nansen.quit()
            otherwise
                error('User canceled')
        end
    catch exception
        switch exception.identifier
            case 'NANSEN:App:ApplicationNotRunning'
                % Continue
            otherwise
                rethrow(exception)
        end
    end
    
    % Run the tutorial initialization
    nansen.app.tutorial.loadProject(tutorial)
end
