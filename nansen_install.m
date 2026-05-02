% ! ! This should only be run if the repository was cloned from GitHub ! !
%
% Please note:
%
%   1) If the default add-on folder is used and userpath is empty, this
%      script will update userpath
%   2) This script will download dependencies for NANSEN
%   3) This script will add NANSEN and dependencies to the search path

function nansen_install(options)

    arguments
        options.SavePath (1,1) logical = true
        options.Modules (1,:) string = string.empty
        options.Update (1,1) logical = false
        options.AddonFolder (1,1) string = missing
    end

    nansenProjectFolder = fileparts(mfilename('fullpath')); % Path to nansen codebase
    nansenToolboxFolder = fullfile(nansenProjectFolder, 'code');
    if isfolder(nansenToolboxFolder)
        addpath( genpath(nansenToolboxFolder) )
    else
        error('NANSEN:Setup:CodeFolderNotFound', ...
              'Could not find folder with code for Nansen')
    end

    if ismissing(options.AddonFolder)
        options.AddonFolder = nansen.config.addons.getDefaultAddonFolder();
    end

    % Suppress a warning which is not relevant for users
    warningIdentifier = 'MATLAB:javaclasspath:jarAlreadySpecified';
    warningCleanup = nansen.common.suppressWarning(warningIdentifier); %#ok<NASGU>

    % Get the AddonManager singleton for the selected add-on folder.
    addonManager = nansen.config.addons.AddonManager.instance( ...
        "reset", options.AddonFolder);

    % We need MatBox first to install other dependencies
    addonManager.downloadAndInstallMatBox()

    % installMissingAddons / updateAddons both include core requirements
    % alongside any selected modules (the resolver defaults to IncludeCore).
    if options.Update
        addonManager.updateAddons(options.Modules);
    else
        numAddonsInstalled = addonManager.installMissingAddons(options.Modules);
        if numAddonsInstalled == 0
            disp([ ...
                'All dependencies are installed. ', ...
                'Use nansen_install(Update=true) to update dependencies.'])
        end
    end

    % Add NANSEN toolbox folder to path if it was not added already
    if ~contains(path(), nansenToolboxFolder)
        addpath(genpath(nansenToolboxFolder))
    end
    if options.SavePath
        status = savepath();
        if status ~= 0
            warning('NANSEN:Setup:SavePathFailed', ...
                ['Could not save the MATLAB path. NANSEN is available for this session, ', ...
                 'but you may need to save the path manually.'])
        end
    end
end
