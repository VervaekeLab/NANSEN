function verifyInstallation(options)
% verifyInstallation - Verify that NANSEN has everything it needs to work

    arguments
        options.MathworksProductMissingAlertMode = "error"
    end

    nansen.internal.setup.checkWidgetsToolboxVersion();
    
    % Check whether required Mathworks products are installed.
    nansen.internal.dependencies.checkRequiredMathworksProducts( ...
        options.MathworksProductMissingAlertMode)

    % Java classpath setup is a recurring pain. Verify that everything is
    % set up correctly before continuing.
    nansen.internal.setup.verifyJavaDependencies()
end
