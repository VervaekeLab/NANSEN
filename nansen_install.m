function nansen_install(dependencyIds, options)
%nansen_install - Install the dependencies of NANSEN and add it to the path
%   nansen_install() downloads the missing community toolboxes that
%   NANSEN needs, adds NANSEN and the toolboxes to the MATLAB search path,
%   saves the path and verifies the installation. Run nansen_install only
%   from a clone of the NANSEN repository.
%
%   nansen_install(dependencyIds) installs only the community toolboxes
%   with the ids in dependencyIds, for example nansen_install("flowreg")
%   or nansen_install(["flowreg","normcorre"]). The ids are listed in
%   the dependencies.nansen.json files of NANSEN and of the modules on the
%   MATLAB search path. An unknown id throws an error that lists the
%   available ids.
%
%   nansen_install(Modules=MODULES) also installs the dependencies of the
%   modules in MODULES. Name a module by its package name
%   ("nansen.module.ophys.twophoton"), by the name in its
%   module.nansen.json file ("Two Photon Imaging") or by the last part of
%   its package name ("twophoton"). An unknown module throws an error that
%   lists the available modules.
%
%   nansen_install(...,Update=TF) updates the selected toolboxes that are
%   already installed when TF is true. With dependency ids, missing
%   toolboxes are installed as well; without them, only installed
%   toolboxes are updated. The default is false.
%
%   nansen_install(...,SavePath=TF) saves the MATLAB search path when TF
%   is true. The default is true.
%
%   nansen_install(...,AddonFolder=FOLDER) installs the toolboxes in
%   FOLDER instead of the default add-on folder of NANSEN. When the
%   default folder is used and userpath is empty, nansen_install sets
%   userpath first.
%
%   Example: Install a toolbox that an error message says is missing
%       nansen_install("flowreg")
%
%   See also nansen.internal.dependencies.assertInstalled,
%   nansen.config.addons.AddonManager

    arguments
        dependencyIds (1,:) string = string.empty
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

    % Check the requested names before anything is downloaded, so that a
    % typo fails fast
    if ~isempty(dependencyIds) && ~isempty(options.Modules)
        error('NANSEN:Setup:DependenciesAndModulesGiven', ...
            ['Specify dependency ids or Modules, not both. Install the ', ...
             'dependencies and the modules with separate calls to ', ...
             'nansen_install.'])
    end
    if ~isempty(options.Modules)
        options.Modules = nansen.internal.dependencies.resolveModuleNames( ...
            options.Modules);
    end
    isInstallingSelectedDependencies = ~isempty(dependencyIds);
    if isInstallingSelectedDependencies
        [dependencies, declaringModules] = ...
            nansen.internal.dependencies.resolveDependencyIds(dependencyIds);
    end

    if ismissing(options.AddonFolder)
        if isempty(userpath())
            nansen.internal.setup.resolveEmptyUserpath()
        end
        options.AddonFolder = nansen.config.addons.getDefaultAddonFolder();
    end

    % Suppress a warning which is not relevant for users
    warningIdentifier = 'MATLAB:javaclasspath:jarAlreadySpecified';
    warningCleanup = nansen.common.suppressWarning(warningIdentifier); %#ok<NASGU>

    % Get the AddonManager singleton for the selected add-on folder.
    % The singleton resets itself if the folder differs from the current instance.
    addonManager = nansen.config.addons.AddonManager.instance( ...
        "AddonFolder", options.AddonFolder);

    if isInstallingSelectedDependencies
        fprintf('Installing %s...\n', strjoin([dependencies.Name], ', '))
    else
        disp('Installing dependencies...')
    end

    % We need MatBox first to install other dependencies
    addonManager.downloadAndInstallMatBox()

    if isInstallingSelectedDependencies
        installSelectedDependencies(addonManager, dependencies, ...
            declaringModules, options.Update)
    elseif options.Update
        % installMissingAddons / updateAddons both include core requirements
        % alongside any selected modules (the resolver defaults to IncludeCore).
        addonManager.updateAddons(options.Modules);
    else
        % installMissingAddons prints its failure summary on its own only
        % when no output is requested, so ask for the summary explicitly
        [~, installationReport] = addonManager.installMissingAddons( ...
            options.Modules, "ShowSummary", true);
        if installationReport.NumAttempted == 0
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

    % The installation check covers core NANSEN only, so it is skipped
    % when only selected dependencies were installed
    if ~isInstallingSelectedDependencies
        fprintf('Verifying installation... ')
        try
            nansen.internal.setup.verifyInstallation()
        catch exception
            throwAsCaller(exception)
        end
        disp('Success!')
    end
end

function installSelectedDependencies(addonManager, dependencies, declaringModules, doUpdate)
%installSelectedDependencies - Install dependencies and add them to path
    addonNames = [dependencies.Name];
    dependencyIds = [dependencies.Id];

    % The add-on manager reads the dependencies of a module from the
    % module's manifest, so it needs the modules that declare them
    moduleNames = unique(declaringModules(declaringModules ~= ""));

    if doUpdate
        % Update the installed dependencies first. The install step below
        % then only downloads the ones that were missing.
        addonManager.updateAddons(moduleNames, "AddonNames", addonNames);
    end
    [~, installationReport] = addonManager.installMissingAddons(moduleNames, ...
        "AddonNames", addonNames, "ShowSummary", true);

    % An installed dependency can be missing from the path, for example if
    % the path was not saved in an earlier session
    for addonName = addonNames
        addonManager.addAddonToMatlabPath(addonName)
    end

    % The add-on manager tracks whether a dependency's setup step (such as
    % compiling MEX files) finished; the installation status tells whether
    % its code is on the path
    dependencyStatus = nansen.internal.dependencies.checkInstallationStatus(dependencies);
    isReady = [dependencyStatus.IsOnPath] & ...
        arrayfun(@(name) addonManager.isAddonInstalled(name), addonNames);
    if ~all(isReady)
        error('NANSEN:Setup:DependencyNotInstalled', ...
            ['%s could not be installed. Fix the problem described above ', ...
             'and run nansen_install again.'], strjoin(addonNames(~isReady), ', '))
    end

    resultNames = string({installationReport.Results.Name});
    resultStatus = string({installationReport.Results.Status});
    installedNames = resultNames(resultStatus == "succeeded");
    if ~isempty(installedNames)
        fprintf('Installed %s.\n', strjoin(installedNames, ', '))
    end

    % After an update, the skipped dependencies are the ones that
    % updateAddons just updated, so the hint to update them is left out
    skippedNames = resultNames(resultStatus == "skipped");
    if ~doUpdate && ~isempty(skippedNames)
        skippedIds = dependencyIds(ismember(addonNames, skippedNames));
        fprintf(['Already installed: %s. Use nansen_install(%s, ', ...
            'Update=true) to update.\n'], strjoin(skippedNames, ', '), ...
            formatIdsForDisplay(skippedIds))
    end
end

function idsText = formatIdsForDisplay(dependencyIds)
%formatIdsForDisplay - Format ids the way a user would type them
    quotedIds = """" + dependencyIds + """";
    if isscalar(quotedIds)
        idsText = quotedIds;
    else
        idsText = "[" + strjoin(quotedIds, ", ") + "]";
    end
end
