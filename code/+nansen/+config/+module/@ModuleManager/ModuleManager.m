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

            numModules = numel(moduleSpecFiles);
            modules = cell(1, numModules);

            % Get module attributes for each module.
            for i = 1:numModules
                str = fileread(moduleSpecFiles{i});
                modules{i} = jsondecode(str).Properties;
                
                modulePackageName = utility.path.pathstr2packagename(fileparts( moduleSpecFiles{i}) );
                splitPackage = strsplit(modulePackageName, '.');
                
                if strcmp( splitPackage{end-1}, 'module' )
                    modules{i}.ModuleCategory = string(missing);
                else
                    modules{i}.ModuleCategory = string(splitPackage{end-1});
                end
                modules{i}.ShortName = splitPackage{end};
                modules{i}.PackageName = modulePackageName;
                modules{i}.isCoreModule = strcmp(modules{i}.ModuleCategory, 'general');
                modules{i}.FolderPath = fileparts( moduleSpecFiles{i});
            end

            obj.ModuleList = cat(1, modules{:});
        end

        function markDirty(obj)
            obj.IsDirty = true;
        end
        
        function markClean(obj)
            obj.IsDirty = false;
        end
    end
end
