classdef SessionMethodsCatalog < utility.data.StorableCatalog
%SessionMethodsCatalog Catalog for session methods
%
%   smCatalog = nansen.config.SessionMethodsCatalog


%   Todo
%       [ ] Remove functions that do not exist in a folder...
%           - Create a method, or do it as part of refresh     


    properties (Constant, Hidden)
        ITEM_TYPE = 'SessionMethod'
    end
    
    methods (Static) % Get empty and default item
        
        function S = getBlankItem()
            % Why would this be a method and not just a property?
            S = struct();
            S.FunctionName = '';
            S.FunctionAlias = '';
            S.PackageName = '';
            S.RootFolder = '';              % Folder containing package
            S.AbsolutePath = '';
        end
        
        function S = getDefaultItem()
        %getDefaultItem Get default item for catalog
            S = eval( sprintf('%s.getBlankItem()', mfilename('class')) );
            
            % Note: No default exists for this item type, so returning the
            % blank item
        end
        
    end 
    
    methods % Constructor
        
        function obj = SessionMethodsCatalog(varargin)
            
            % Superclass constructor. Loads given (or default) archive 
            obj@utility.data.StorableCatalog(varargin{:})
            
            if ~nargout
                utility.data.StorableCatalogApp(obj)
                clear obj
            end
        end
        
    end
    
    methods % Public methods
        
        function refresh(obj)
        %Refresh Check known directories for methods and update catalog
        
            pathList = nansen.session.listSessionMethods();
            functionNames = cell(1, numel(pathList));
                       
            % Add session methods that are not part of the catalog.
            for i = 1:numel(pathList)
                tmpItem = obj.getSessionMethodItemFromPath(pathList{i});
                functionNames{i} = tmpItem.FunctionName;
                
                if ~obj.ismember(tmpItem.FunctionName)
                    obj.insertItem(tmpItem)
                end
            end
            
            % Remove session methods that are not found during listing.
            for i = numel(obj.Data):-1:1
                thisName = obj.Data(i).FunctionName;
                if ~ismember(functionNames, thisName)
                    obj.removeItem(i)
                    warning('Method "%s" was not found on the path and is removed from the list of session methods', thisName)
                end
            end
        end
        
        function addOptionsAlternative(obj)
            
            for i = 1:numel(obj.Data)
                                
                obj.Data(i).OptionsAlternatives = ...
                    obj.getOptionsAlternatives(obj.Data(i));
                
            end
        end
        
        function S = getSessionMethodItemFromPath(obj, pathStr)
        %getSessionMethodItemFromPath Get info struct for session method
        %   
        %   S = getSessionMethodItemFromPath(obj, pathStr)
        %
        %   S contains the following fields:
        %         FunctionName
        %         FunctionAlias
        %         PackageName
        %         RootFolder
        %         AbsolutePath
        %
        %   Example:        
        %       smc = nansen.config.SessionMethodsCatalog()
        %       S = smc.getSessionMethodItemFromPath(pathStr)
        
            [folderPath, fileName, ext] = fileparts(pathStr); 
            assert(strcmp(ext, '.m'), 'Input must be the path of a .m file')
        
            S = obj.getBlankItem();
            S.AbsolutePath = pathStr;
            
            S.FunctionName = utility.path.abspath2funcname(pathStr);
            S.FunctionAlias = fileName;
            S.PackageName = utility.path.pathstr2packagename(folderPath);

            % Get root folder, folder containing package. Match as few 
            % characters as possible before package folder
            expression = ['.*?(?=\' filesep '\+)'];
            S.RootFolder = regexp(folderPath, expression, 'match', 'once');
            
        end

        function S = addSessionMethodFromPath(obj, pathStr)
            
            S = obj.getSessionMethodItemFromPath(pathStr);
            obj.insertItem(S)

            if ~nargout
                clear S
            end
        end
    end
    
    methods (Access = protected)
        
        function item = validateItem(obj, item)
            item = validateItem@utility.data.StorableCatalog(obj, item);
            
            if isfield(obj.Data, 'OptionsAlternatives')
                if ~isfield(item, 'OptionsAlternatives')
                    item.OptionsAlternatives = obj.getOptionsAlternatives(item);
                end
            end
        end
        
        function S = cleanStructOnSave(~, S)
            % Should not save OptionsAlternatives field.
            if isfield(S.Data, 'OptionsAlternatives')
                S.Data = rmfield(S.Data, 'OptionsAlternatives');
            end
        end

    end
    
    methods (Static)
        
        function pathString = getDefaultFilePath()
        %getDefaultFilePath Get filepath for loading/saving filepath settings  
            
            import nansen.config.project.ProjectManager
            
            varName = 'SessionMethodsCatalog';
            try
                pathString = ProjectManager.getProjectCatalogPath(varName);
            catch
                pathString = '';
            end
        end

        function optAlternatives = getOptionsAlternatives(item)
        %getOptionsAlternatives Get option-alternatives for a smethod item
        
            pathstr = which(item.FunctionName);
            if isempty(pathstr)
                addpath(item.RootFolder)
                           
                pathstr = which(item.FunctionName);
                if isempty(pathstr)
                    optAlternatives = {'Not Available'}; return
                end
            end
            
            optManager = nansen.OptionsManager(item.FunctionName);
            optAlternatives = optManager.AvailableOptionSets;
            
        end
    end
    
end