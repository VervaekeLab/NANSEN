S = ver("widgets");
if isempty(S)
    nansen.internal.setup.installWidgetsToolbox()
end
try
    nansen.internal.setup.checkWidgetsToolboxVersion();
catch
    nansen.internal.setup.installWidgetsToolbox();
end

% Run the tutorial initialization
nansen.app.tutorial.loadProject()
