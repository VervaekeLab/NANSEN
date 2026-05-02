S = ver("widgets");
if isempty(S)
    nansen.internal.setup.installWidgetsToolbox()
end
try
    nansen.internal.setup.checkWidgetsToolboxVersion();
catch
    nansen.internal.setup.installWidgetsToolbox();
end

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
