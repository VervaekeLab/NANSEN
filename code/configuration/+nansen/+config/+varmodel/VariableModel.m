classdef VariableModel < utility.data.TabularArchive
    
    % Todo: 
    %   [x] Add IsEditable? I.e is it possible to change the filename
    %   [x] Add subfolders. I.e if session folder should be further organized in subfolders. 
    %   [ ] Methods for above...
    
    %   [ ] Flag for whether model data has changed....
    
    
    properties (Constant)
%         FileTypes
%         DataAdapters
    end
    
    properties (Constant, Access = protected)
        ITEM_TYPE = 'Variable'
    end
    
    properties (Dependent, SetAccess = private)
        VariableNames
        NumVariables
    end
    
    properties (Access = private)
        %DataLocationModel % Todo: needed?
    end
    
    
    methods (Static) % Get empty and default item
        
        function S = getEmptyItem()
            
            S = struct(...
                'VariableName', '', ...
                'IsDefaultVariable', false, ... 
                'FileNameExpression', '', ...
                'DataLocation', '', ...
                'FileType', '', ...
                'FileAdapter', '', ...
                'Subfolder', '');
            
        end
        
        function S = getDefaultItem(varName)
            S = nansen.setup.model.FilePathSettingsEditor.getEmptyItem;

            S.VariableName = varName;
            S.DataLocation = 'Processed';
            S.FileType = '.mat';
            S.FileAdapter = 'Default';
            
        end
        
    end 
        
    methods % Constructor
        
        function obj = VariableModel(varargin)
            
            obj@utility.data.TabularArchive(varargin{:})
            
            if isempty(obj.FilePath)
                obj.FilePath = obj.getDefaultFilePath();
            end
                         
            obj.load()
            
            obj.updateDefaultValues() %  This should be temporary, to account for changes made during development
             
        end
        
    end
    
    methods % Set/get methods
    
        function numVariable = get.NumVariables(obj)
            numVariable = numel(obj.Data);
        end
        
        function variableNames = get.VariableNames(obj)
            variableNames = obj.ItemNames;
        end
        
    end
    
    methods
        
        function setGlobal(obj)
            global dataFilePathModel
            dataFilePathModel = obj;
        end
        
        function load(obj)
        %load Load list (csv or xml) with required/supported variables
            obj.tempFixVariableNameInFile()
            load@utility.data.TabularArchive(obj)
        end
        
        function view(obj)
            
            T = struct2table(obj.Data);
            disp(T)
            
        end

        function updateDefaultValues(obj)
            
            str = 'Not implemented yet';
            
            for i = 1:numel(obj.Data)
                if isempty( obj.Data(i).FileAdapter ) || strcmp(obj.Data(i).FileAdapter, str)
                    obj.Data(i).FileAdapter = 'Default';
                end
            end
            
        end
        
    end
    
    methods (Hidden, Access = ?nansen.config.varmodel.VariableModelApp)
        function setVariableList(obj, S)
            obj.Data = S;
        end
    end
    
    methods (Access = protected)
        
        function item = validateItem(obj, item)
            
            if isempty(item.FileAdapter)
                % Todo: Have defaults for different filetypes...
                item.FileAdapter = 'Default';
            end
            
        end
        
    end
    
    methods (Access = private)
               
        function tempFixVariableNameInFile(obj)
        %tempFixVariableNameInFile Rename VariableList to Data...    
            if isfile(obj.FilePath)
                S = whos('-file', obj.FilePath);
               
                if any(strcmp({S.name}, 'VariableList'))
                    S = load(obj.FilePath);
                    obj.Data = S.VariableList;
                    obj.Preferences = struct();
                    
                    obj.save()
                end                    
                
            end
            
        end
        
        % Todo: Should be external...
        % Todo: Should depend on user-selected template model..
        function variableList = initializeVariableList(~)

            import nansen.config.varmodel.template.*
            variableList = twophoton.getVariableList();

        end
    end
    
    methods (Static)
        
        function pathString = getDefaultFilePath()
        %getDefaultFilePath Get filepath for loading/saving filepath settings   
            fileName = 'FilePathSettings';
            try
                pathString = nansen.config.project.ProjectManager.getProjectSubPath(fileName);
            catch
                pathString = '';
            end
        end

    end
    
end