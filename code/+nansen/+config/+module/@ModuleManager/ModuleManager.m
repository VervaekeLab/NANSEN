classdef ModuleManager < handle
%ModuleManager A manager for managing a modules to include in a project
%
%   A simple class for listing available modules in nansen. More functionality
%   might be needed later.

    properties (SetAccess = protected)
        ModuleList struct = struct() % List of modules (table or struct array)
    end

    properties (Hidden)
        IsDirty = false
    end

    properties (Constant, Access = private)
        ModuleRootPath = nansen.common.constant.ModuleRootDirectory()
    end

    methods

        function obj = ModuleManager()
        %ModuleManager Construct an instance of this class
            obj.getModuleList()
        end
    end

    methods

        function moduleTable = listModules(obj, flag)
        %listModules Display a table of modules
        %
        %   Syntax:
        %       moduleTable = obj.listModules() list all modules
        %
        %       moduleTable = obj.listModules(flag) list modules according
        %       to a flag. Flag can be 'all', 'required', 'optional'

            if nargin < 2 || isempty(flag)
                flag = 'all';
            end

            moduleTable = struct2table(obj.ModuleList);

            stringVars = ["Name", "Description", ...
                "ModuleCategory", "ShortName", "PackageName"];
            for iVarName = stringVars
                moduleTable.(iVarName) = string(moduleTable.(iVarName));
            end

            if ~strcmp(flag, 'all')
                if strcmp(flag, 'required')
                    moduleTable = moduleTable(moduleTable.isCoreModule, :);
                elseif strcmp(flag, 'optional')
                    moduleTable = moduleTable(~moduleTable.isCoreModule, :);
                else
                    validatestring(flag, {'required', 'optional'}, 2)
                end
            end
        end
    end

    methods (Access = protected)

        function getModuleList(obj)
        % getModuleList List available modules
        %
        %   This method will list all available modules in the root module
        %   directory. It will look for json files within the module, so
        %   this function will only work properly if there is one and only
        %   on valid json file within a module directory.

            % % Deprecated: Look only in ModuleRootPath for modules
            % % moduleDirectories = utility.path.listSubDir(obj.ModuleRootPath, '', {}, 4);
            % % moduleSpecFiles = utility.path.listFiles(moduleDirectories, '.json');

            % Look for all packages on path with nansen.module prefix
            s = what(fullfile('+nansen', '+module'));

            % Need to filter out the template here, as it will be detected if
            % the content of the +nansen/+module/resources folder is on
            % MATLAB's search path
            moduleFolders = {s.path};
            moduleFolders(contains(moduleFolders, 'module_folder_template')) = [];

            moduleSpecFiles = recursiveDir(moduleFolders, ...
                'Expression', 'module.nansen', ...
                'IgnoreList', 'module_folder_template', ...
                'OutputType', 'FilePath', ...
                'FileType', 'json');

            [moduleSpecFiles, packageNames] = obj.keepFirstFilePerPackage(moduleSpecFiles);

            numModules = numel(moduleSpecFiles);
            modules = cell(1, numModules);

            % Get module attributes for each module.
            for i = 1:numModules
                str = fileread(moduleSpecFiles{i});
                moduleProperties = jsondecode(str).Properties;

                modulePackageName = packageNames{i};
                splitPackage = strsplit(modulePackageName, '.');

                % The category is module metadata. Modules that still live
                % in a category folder (+ophys, +general) fall back to the
                % folder name; modules directly under +module must declare
                % it in their specification file.
                if isfield(moduleProperties, 'Category')
                    moduleCategory = string(moduleProperties.Category);
                    moduleProperties = rmfield(moduleProperties, 'Category');
                elseif strcmp( splitPackage{end-1}, 'module' )
                    moduleCategory = string(missing);
                else
                    moduleCategory = string(splitPackage{end-1});
                end

                modules{i} = moduleProperties;
                modules{i}.ModuleCategory = moduleCategory;
                modules{i}.ShortName = splitPackage{end};
                modules{i}.PackageName = modulePackageName;
                modules{i}.isCoreModule = strcmp(modules{i}.ModuleCategory, 'general');
                modules{i}.FolderPath = fileparts( moduleSpecFiles{i});
                requirementManifestPath = fullfile(modules{i}.FolderPath, 'dependencies.nansen.json');
                if isfile(requirementManifestPath)
                    modules{i}.RequirementManifestPath = requirementManifestPath;
                else
                    modules{i}.RequirementManifestPath = "";
                end
            end

            obj.ModuleList = cat(1, modules{:});
            obj.assertUniqueShortNames()
        end

        function assertUniqueShortNames(obj)
        %assertUniqueShortNames Error if different packages share a short name
        %
        %   A module's short name is the last part of its package name. Two
        %   different module packages must not have the same short name,
        %   also when they are in different category folders, for example
        %   nansen.module.alpha.example and nansen.module.beta.example.
            if isempty(obj.ModuleList); return; end
            shortNames = string({obj.ModuleList.ShortName});
            [uniqueNames, ~, groupIndex] = unique(shortNames);
            isDuplicated = accumarray(groupIndex(:), 1) > 1;
            if any(isDuplicated)
                duplicatedNames = uniqueNames(isDuplicated);
                clashingEntries = obj.ModuleList(ismember(shortNames, duplicatedNames));
                entryDescriptions = string({clashingEntries.PackageName}) ...
                    + " in " + string({clashingEntries.FolderPath});
                error('NANSEN:ModuleManager:DuplicateModuleName', ...
                    ['Module short names must be unique. The name(s) "%s" ', ...
                     'are used by more than one module package:\n    %s\n', ...
                     'Rename or remove one of them from the MATLAB path.'], ...
                    strjoin(duplicatedNames, '", "'), ...
                    strjoin(entryDescriptions, newline + "    "))
            end
        end

        function markDirty(obj)
            obj.IsDirty = true;
        end

        function markClean(obj)
            obj.IsDirty = false;
        end
    end

    methods (Static, Access = private)

        function [specificationFiles, packageNames] = keepFirstFilePerPackage(specificationFiles)
        %keepFirstFilePerPackage Keep one module specification file per package
        %
        %   The same package can be found in more than one folder on the
        %   MATLAB path, for example in a cloned repository and in an
        %   installed copy. specificationFiles is in path order, and only
        %   the file from the folder that comes first on the path is kept.
        %   packageNames holds the package name of each kept file.
            packageNames = cellfun(@(filePath) utility.path.pathstr2packagename(fileparts(filePath)), ...
                specificationFiles, 'UniformOutput', false);
            [packageNames, firstIndices] = unique(packageNames, 'stable');
            specificationFiles = specificationFiles(firstIndices);
        end
    end
end
