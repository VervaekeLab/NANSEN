function installFexSubmission(addonInfo, installationDirectory)
    
    if nargin < 2
        installationDirectory = nansen.common.constant.DefaultAddonPath();
    end
    
    % Download the file containing the addon toolbox
    tempFilepath = [tempname, '.zip'];
    
    try
        tempFilepath = websave(tempFilepath, addonInfo.DownloadUrl);
        fileCleanupObj = onCleanup( @(fname) delete(tempFilepath) );
    catch ME
        rethrow(ME)
    end

    pkgInstallationDir = fullfile(installationDirectory, addonInfo.Name); % todo
    unzip(tempFilepath, pkgInstallationDir);

    % Delete the temp zip file
    clear fileCleanupObj

    addpath(genpath(pkgInstallationDir))
end