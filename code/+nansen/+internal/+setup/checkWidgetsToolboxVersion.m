function checkWidgetsToolboxVersion()
    
    S = ver("widgets");
    if isempty(S); return; end
    
    if ~any( strcmp( {S.Version}, '1.3.330' ) )
        downloadURL = sprintf('<a href="matlab:nansen.internal.setup.installWidgetsToolbox" style="font-weight:bold">%s</a>', 'Click to install');
        warning('backtrace', 'off')
        warning('Nansen requires version 1.3.330 of the Widgets Toolbox whereas the current version of the Widgets Toolbox is %s.', S.Version)
        warning('backtrace', 'on')
        error('Please install v1.3.330 of the Widgets Toolbox: %s', downloadURL)
    end
end
