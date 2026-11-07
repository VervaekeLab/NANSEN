function packageNames = resolveModuleNames(moduleNames)
%resolveModuleNames - Convert module names to module package names
%   packageNames = resolveModuleNames(moduleNames) returns the package
%   name of each module in moduleNames. Name a module by its package name
%   ("nansen.module.ophys.twophoton"), by the name in its
%   module.nansen.json file ("Two Photon Imaging") or by the last part of
%   its package name ("twophoton"). The last two are matched without
%   regard to letter case.
%
%   resolveModuleNames throws an error that lists the modules on the
%   MATLAB search path if a name matches no module, or matches more than
%   one module.
%
%   See also listModules, resolveDependencyIds

    arguments
        moduleNames (1,:) string {mustBeNonzeroLengthText}
    end

    modules = nansen.internal.dependencies.listModules();

    packageNames = strings(size(moduleNames));
    isUnknown = false(size(moduleNames));
    for i = 1:numel(moduleNames)
        isMatch = matchModules(modules, moduleNames(i));
        matchingPackageNames = [modules(isMatch).PackageName];

        if isscalar(matchingPackageNames)
            packageNames(i) = matchingPackageNames;
        elseif isempty(matchingPackageNames)
            isUnknown(i) = true;
        else
            error("NANSEN:Dependencies:AmbiguousModuleName", ...
                "The name ""%s"" matches more than one module: %s. " + ...
                "Name the module by its package name instead.", ...
                moduleNames(i), strjoin(matchingPackageNames, ", "))
        end
    end

    if any(isUnknown)
        error("NANSEN:Dependencies:UnknownModule", "%s", ...
            createUnknownModuleMessage(moduleNames(isUnknown), modules))
    end
end

function isMatch = matchModules(modules, moduleName)
%matchModules - Find the modules that a name refers to
    isMatch = false(size(modules));
    if isempty(modules)
        return
    end
    isMatch = [modules.PackageName] == moduleName ...
        | strcmpi([modules.Name], moduleName) ...
        | strcmpi([modules.ShortName], moduleName);
end

function message = createUnknownModuleMessage(unknownNames, modules)
%createUnknownModuleMessage - Describe unknown names and list modules
    quotedNames = strjoin("""" + unknownNames + """", ", ");
    if isscalar(unknownNames)
        message = sprintf("No module named %s was found.", quotedNames);
    else
        message = sprintf("No modules named %s were found.", quotedNames);
    end

    if isempty(modules)
        message = message + newline + newline + ...
            "No modules were found on the MATLAB search path.";
    else
        [~, sortIndices] = sort([modules.PackageName]);
        modules = modules(sortIndices);
        header = ["Package name", "Name", "Short name"];
        packageColumn = pad([header(1), modules.PackageName]);
        nameColumn = pad([header(2), modules.Name]);
        shortNameColumn = [header(3), modules.ShortName];
        tableLines = "    " + packageColumn + "   " + nameColumn + ...
            "   " + shortNameColumn;
        message = message + newline + newline + ...
            "Available modules:" + newline + strjoin(tableLines, newline);
    end

    message = message + newline + newline + ...
        "NANSEN finds modules in +nansen/+module package folders on " + ...
        "the MATLAB search path. If the module is installed but not " + ...
        "listed, add its repository folder with " + ...
        "addpath(genpath(<repository folder>)) and try again.";
end
