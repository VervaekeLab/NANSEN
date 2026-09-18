function modules = listModules()
%listModules - List the NANSEN modules on the MATLAB search path
%   MODULES = listModules() returns a struct array with one element for
%   each module specification file (module.nansen.json) below a
%   +nansen/+module package folder on the MATLAB search path. MODULES has
%   these fields:
%       PackageName  - Package name, e.g. "nansen.module.ophys.twophoton"
%       Name         - Name from the module specification file
%       ShortName    - Last part of the package name, e.g. "twophoton"
%       ManifestPath - Path of the dependencies.nansen.json file of the
%                      module, or "" if the module has none
%
%   listModules calls only MATLAB functions, so it works before the
%   community toolboxes that NANSEN depends on are installed.
%
%   See also resolveModuleNames, resolveDependencyIds,
%   nansen.config.module.ModuleManager

    moduleFolders = findModuleFolders();

    modules = repmat(struct( ...
        'PackageName', "", ...
        'Name', "", ...
        'ShortName', "", ...
        'ManifestPath', ""), 1, numel(moduleFolders));

    for i = 1:numel(moduleFolders)
        specification = jsondecode(fileread( ...
            fullfile(moduleFolders(i), "module.nansen.json")));
        packageName = string(utility.path.pathstr2packagename( ...
            char(moduleFolders(i))));
        packageNameParts = split(packageName, ".");

        modules(i).PackageName = packageName;
        modules(i).Name = string(specification.Properties.Name);
        modules(i).ShortName = packageNameParts(end);

        manifestPath = fullfile(moduleFolders(i), "dependencies.nansen.json");
        if isfile(manifestPath)
            modules(i).ManifestPath = manifestPath;
        end
    end

    % A module is found twice when two copies of it are on the path, for
    % example a clone and a git worktree of the same repository. WHAT lists
    % folders in path order, so the copy that MATLAB uses comes first.
    if ~isempty(modules)
        [~, firstIndices] = unique([modules.PackageName], "stable");
        modules = modules(firstIndices);
    end
end

function moduleFolders = findModuleFolders()
%findModuleFolders - Find folders that contain a module specification file
    packageFolderInfo = what(fullfile("+nansen", "+module"));

    moduleFolders = strings(1, 0);
    for packageFolder = string({packageFolderInfo.path})
        specificationFiles = dir(fullfile(packageFolder, "**", "module.nansen.json"));
        moduleFolders = [moduleFolders, string({specificationFiles.folder})]; %#ok<AGROW>
    end

    % NANSEN ships a template for new modules, which has a specification
    % file but is not a module
    moduleFolders(contains(moduleFolders, "module_folder_template")) = [];
end
