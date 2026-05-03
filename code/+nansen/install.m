function install(options)
% install - Install missing nansen dependencies.
%
%   nansen.install() installs any missing core dependencies into the
%   default add-on folder.
%
%   nansen.install(Name=Value) options:
%       AddonFolder - Folder to install add-ons into. Defaults to NANSEN's
%                     default add-on folder.
%       Modules     - Module package names whose dependencies should also
%                     be installed (workflow-scoped deps included by
%                     default).
%       Update      - Update already-installed add-ons in addition to
%                     installing missing ones (default: false).

    arguments
        options.AddonFolder (1,1) string = missing
        options.Modules (1,:) string = string.empty
        options.Update (1,1) logical = false
    end

    if ismissing(options.AddonFolder)
        options.AddonFolder = nansen.config.addons.getDefaultAddonFolder();
    end

    addonManager = nansen.config.addons.AddonManager.instance( ...
        "AddonFolder", options.AddonFolder);
    addonManager.downloadAndInstallMatBox();

    if options.Update
        addonManager.updateAddons(options.Modules);
    else
        addonManager.installMissingAddons(options.Modules);
    end

    nansen.internal.setup.verifyInstallation()
end
