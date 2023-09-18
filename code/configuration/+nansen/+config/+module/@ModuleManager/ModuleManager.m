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
        ModuleRootPath = fullfile(nansen.rootpath, 'modules', '+nansen')
    end
    
    methods
        
        function obj = ModuleManager()
        %ModuleManager Construct an instance of this class
            obj.getModuleList()
        end
        
    end
    
    methods
        
        function moduleTable = listModules(obj)
        %listModules Display a table of modules
            moduleTable = struct2table(obj.ModuleList);
            
            for iVar = 1:size(moduleTable, 2)
                thisVarName = moduleTable.Properties.VariableNames{iVar};
                moduleTable.(thisVarName) = string(moduleTable.(thisVarName));
            end
        end
        
    end

    methods (Access = protected)
        
        function getModuleList(obj)
        % getModuleList List available modules
            moduleDirectories = utility.path.listSubDir(obj.ModuleRootPath, '', {}, 3);
            moduleSpecFiles = utility.path.listFiles(moduleDirectories, 'json');

            numModules = numel(moduleSpecFiles);
            modules = cell(1, numModules);

            for i = 1:numModules
                str = fileread(moduleSpecFiles{i});
                modules{i} = jsondecode(str).attributes;
                
                modulePackage = utility.path.pathstr2packagename(fileparts( moduleSpecFiles{i}) );
                splitPackage = strsplit(modulePackage, '.');
                
                modules{i}.moduleCategory = splitPackage{3};
                modules{i}.moduleName = splitPackage{4};
                modules{i}.modulePackage = modulePackage;
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
