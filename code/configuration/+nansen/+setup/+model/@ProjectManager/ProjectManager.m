classdef ProjectManager < handle
%setup.model.ProjectManager Interface for managing projects
%
%   The purpose of this class is to simplify the process of listing
%   projects, adding new projects and changing the current project.

% Todo:
%   [ ] Make abstract class and create this as subclass 
%   [ ] Same with metatable catalog

    properties
        Catalog             % A catalog of available projects
    end
    
    properties (SetAccess = private)
        CatalogPath         % Path where catalog is saved
    end
    
    
    methods
       
        function obj = ProjectManager()
            % Create instance of the project manager class
            obj.CatalogPath = obj.getCatalogPath();
            obj.loadCatalog()
        end
       
        function disp(obj)
        %disp Override display function to show table of projects.
            titleTxt = sprintf(['<a href = "matlab: helpPopup %s">', ...
                'ProjectManager</a> with available projects:'],class(obj));
            
            T = struct2table(obj.Catalog);
            fprintf('%s\n\n', titleTxt)
            disp(T)
        end
        
        function loadCatalog(obj)
        %loadCatalog Load the project catalog
            if ~exist(obj.CatalogPath, 'file')
                newCatalog = struct('Name', {}, 'Description', {}, 'Path', {});
                S.projectCatalog = newCatalog;
            else
                S = load(obj.CatalogPath, 'projectCatalog');
            end
            
            obj.Catalog = S.projectCatalog;
        end
       
        function saveCatalog(obj)
        %saveCatalog Save the project catalog
            projectCatalog = obj.Catalog;  %#ok<NASGU
            save(obj.CatalogPath, 'projectCatalog')
        end
        
        function addProject(obj, name, description, pathStr)
        %addProject Add project to the project catalog.
        
            % Check that project with given name does not already exist
            isNameOccupied = any(contains({obj.Catalog.Name}, name));
            if isNameOccupied
                errMsg = 'Project with this name already exists.';
                error('Nansen:ProjectExists', errMsg)
            end
            
            nextInd = numel(obj.Catalog) + 1;
            
            obj.Catalog(nextInd).Name = name;
            obj.Catalog(nextInd).Description = description;
            obj.Catalog(nextInd).Path = pathStr;
            
            obj.saveCatalog()
            
        end
       
        function removeProject(obj, name)
            
            IND = contains({obj.Catalog.Name}, name);
            
            if any(IND)
                obj.Catalog(IND) = [];
                fprintf('Project "%s" removed from project catalog', name)
            end
        end
       
        function s = getProject(obj, name)
        %getProject Get project entry given its name 
            IND = contains({obj.Catalog.Name}, name);
            
            if any(IND)
                s = obj.Catalog(IND);
            else
                s = struct.empty;
            end
            
        end
        
        function changeProject(obj, name)
            
            projectEntry = obj.getProject(name);
            
            if isempty(projectEntry)
                errMsg = sprintf('Project with name "%s" does not exist', name);
                error('Nansen:ProjectNonExistent', errMsg) %#ok<SPERR>
            end
                        
            setpref('Nansen', 'CurrentProject', projectEntry.Name)
            setpref('Nansen', 'CurrentProjectPath', projectEntry.Path)
            
        end
        
    end
   
    methods (Static)
        
        function pathStr = getCatalogPath()
            
            % Get default project path
            nansenRoot = utility.path.getAncestorDir(nansen.rootpath, 1);
            projectRootPath = fullfile(nansenRoot, '_userdata', 'projects');
            if ~exist(projectRootPath, 'dir'); mkdir(projectRootPath); end
            
            % Add project details to project catalog file
            pathStr = fullfile(projectRootPath, 'project_catalog.mat');
        end
        
        function pathStr = getProjectSubPath(keyword)
        %getProjectSubPath Get a filepath within given current project
        %
        %   pathStr = getProjectSubPath(keyword) returns the pathStr for a
        %   file or folder belonging to the current project. Keyword is a
        %   descriptor for which file or folder to get the pathStr for. Use
        %   this function for standardizing the filepath for different
        %   files and folders belonging to a project.
        %  
        %   Supported keywords:
        %
        %       MetaTableCatalog
        %       MetaTable

            projectRootDir = getpref('Nansen', 'CurrentProjectPath', '');
            
            % Abort if project root directory is empty (non-existent)
            if isempty(projectRootDir)
                pathStr = '';
                return
            end
            
            % Determine path folder (and filename if relevant) based on
            % input keyword
            switch keyword
                case 'MetaTableCatalog'
                    saveDir = fullfile(projectRootDir, 'Metadata Tables');
                    fileName = 'metatable_catalog.mat';
                case 'MetaTable'
                    saveDir = fullfile(projectRootDir, 'Metadata Tables');
                case 'FilePathSettings'
                    saveDir = fullfile(projectRootDir, 'Configurations');
                    fileName = 'filepath_settings.mat';
                case 'DataLocationSettings'
                    saveDir = fullfile(projectRootDir, 'Configurations');
                    fileName = 'datalocation_settings.mat';
                    
            end
            
            % Make folder if it does not exist
            if ~exist(saveDir, 'dir');  mkdir(saveDir);    end
            
            % Prepare output, either file- or folderpath
            if exist('fileName', 'var')
                pathStr = fullfile(saveDir, fileName);
            else
                pathStr = saveDir;
            end
            
            
        end
      
        function pathStr = getFilePath(keyword)
            pathStr = nansen.setup.model.ProjectManager.getProjectSubPath(keyword);
        end
   end
   
    
end