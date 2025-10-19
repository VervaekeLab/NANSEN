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
nansen.internal.setup.checkRequiredMathworksProducts('error')

% Run the tutorial initialization
nansen.app.tutorial.loadProject()
