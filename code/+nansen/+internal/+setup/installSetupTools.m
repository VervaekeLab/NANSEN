function installSetupTools()

    installationDirectory = nansen.common.constant.DefaultAddonPath();
    installationDirectory = fullfile(installationDirectory, 'general_toolboxes');
    
    info = struct();
    info.DownloadUrl = 'https://github.com/ehennestad/setuptools-matlab/archive/refs/heads/main.zip';
    info.Name = 'Setuptools-Matlab';
    nansen.internal.setup.installFexSubmission(info, installationDirectory)
end