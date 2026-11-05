function moduleEntry = findModuleEntry()
%findModuleEntry Return the ModuleManager entry for the two-photon module
%
%   Discovery scans the MATLAB path for +nansen/+module packages, so the
%   module's code folder must be on the path when this is called. Errors
%   if the module is not discovered, because every test in this package
%   depends on it.

    moduleManager = nansen.config.module.ModuleManager();
    moduleList = moduleManager.ModuleList;

    packageNames = string({moduleList.PackageName});
    isTarget = packageNames == twophotontest.helper.modulePackageName();

    if ~any(isTarget)
        error('twophotontest:ModuleNotFound', ...
            ['The module "%s" was not discovered. Discovered modules: %s. ', ...
             'Is the module''s code folder on the MATLAB path?'], ...
            twophotontest.helper.modulePackageName(), strjoin(packageNames, ', '))
    end

    moduleEntry = moduleList(isTarget);
end
