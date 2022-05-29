classdef Project < handle
   
    % Work in progress.
    
    % This object should reflect the content of a project folder and have
    % methods for interacting with data in the project folder.
    
    
    properties (Constant, Hidden)
        % Todo: Folder property, with subfields?
        METATABLE_FOLDER_NAME = 'Metadata Tables';
        CONFIG_FOLDER_NAME = 'Configurations';
    end
   
    properties
        Name
        PackageName
    end
    
    properties (Access = private)
        FolderPath
        
    end
    
    properties (Dependent)
        MetatableCatalog
        DataLocationModel
        VariableModel
    end
    
    properties (Access = private)
        MetatableCatalog_   % internal store if catalog is already loaded. However, this would not be up to date it the catalog is changed. Think it is better that this is just a dependent property... 
        
    end

    
    methods
        function obj = Project(projectName, projectFolder)
            
            obj.Name = projectName;
            obj.PackageName = strcat('+', obj.Name);
            
            obj.FolderPath = projectFolder;
        end
    end
    
    methods
        function initializeProjectFolder(obj)
            % Todo: Create all folders.
        end

        
    end
    
    methods (Access = ?nansen.config.project.ProjectManager)
        
        function renameProject(obj, newName)
            
        end
        
    end
    
    methods % Set/get
        
        function metatableCatalog = get.MetatableCatalog(obj)
            filePath = obj.getCatalogPath('MetaTableCatalog');
            metatableCatalog = nansen.metadata.MetaTableCatalog(filePath);
        end
        
        function dataLocationModel = get.DataLocationModel(obj)
            filePath = obj.getCatalogPath('DataLocationModel');
            dataLocationModel = nansen.config.dloc.DataLocationModel(filePath);
        end
        
        function variableModel = get.VariableModel(obj)
            filePath = obj.getCatalogPath('VariableModel');
            variableModel = nansen.config.varmodel.VariableModel(filePath);
        end
        
    end
    
    methods (Access = private)
        
        function filePathStr = getCatalogPath(obj, catalogName)
        %getCatalogPath Get absolute path for catalog as character vector 
        
            switch catalogName
                
                case 'MetaTableCatalog'
                    foldername = obj.METATABLE_FOLDER_NAME;
                    filename = 'metatable_catalog.mat';
                    
                case 'DataLocationModel'
                    foldername = obj.CONFIG_FOLDER_NAME;
                    filename = 'datalocation_settings.mat';
                    
                case 'VariableModel'
                    foldername = obj.CONFIG_FOLDER_NAME;
                    filename = 'filepath_settings.mat';                    
            end
            
            folderPathStr = fullfile(obj.FolderPath, foldername);
            filePathStr = fullfile(folderPathStr, filename);
        end
        
    end
   
end