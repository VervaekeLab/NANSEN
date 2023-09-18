classdef ModuleManager < handle
%ModuleManager A manager for managing a modules to include in a project

    properties (SetAccess = protected)
        ModuleList struct = struct() % List of modules (table or struct array)
    end

    properties
        SelectedModules
    end

    properties (Hidden)
        IsDirty = false
    end
    
    properties (Constant, Access = private)
        ModuleRootPath = fullfile(nansen.rootpath, 'modules')
    end
    
    methods
        
        function obj = ModuleManager()
        %ModuleManager Construct an instance of this class

            % Assign the path to the directory where addons are saved
            obj.getModuleList()
        end
        
    end
    
    methods
        
        function moduleTable = listModules(obj)
        %listModules Display a table of modules
            moduleTable = struct2table(obj.ModuleList);
        end
        
    end

    methods (Access = protected)
        
        function getModuleList(obj)
        % getModuleList
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
    
    methods (Access = protected)
        
        function addonIdx = getAddonIndex(obj, addonIdx)
        %getAddonIndex Get index (number) of addon in list given addon name  
            
            if isa(addonIdx, 'char')
                addonIdx = strcmpi({obj.AddonList.Name}, addonIdx);
            end
            
            if isempty(addonIdx)
                error('Something went wrong, addon was not found in list.')
            end
            
        end
    
    end
    
    methods (Hidden, Access = protected) 
               
        function pathStr = getPathForAddonList(obj)
        %getPathForAddonList Get path where local addon list is saved.
        
            rootDir = nansen.rootpath();
            pathStr = fullfile(rootDir, '_userdata', 'settings');
            
            if ~exist(pathStr, 'dir'); mkdir(pathStr); end
            
            pathStr = fullfile(pathStr, 'installed_addons.mat');
        end
        
    end

end

