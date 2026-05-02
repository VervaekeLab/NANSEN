% Prepare environment and run tutorial initialization 
    
% run install if nansen dependencies are missing
deps = nansen.internal.dependencies.resolveRequirements('MissingOnly', false);
if ~isempty(deps)
    nansen_install()
end

S = ver("widgets"); % NB: should be handled via nansen_install
if isempty(S)
    nansen.internal.setup.installWidgetsToolbox()
end

nansen.internal.setup.checkWidgetsToolboxVersion();

% Check whether required Mathworks products are installed.
nansen.internal.dependencies.checkRequiredMathworksProducts('error')

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
nansen.app.tutorial.loadProject()
