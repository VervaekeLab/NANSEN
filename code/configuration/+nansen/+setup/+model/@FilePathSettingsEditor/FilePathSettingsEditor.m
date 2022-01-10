classdef FilePathSettingsEditor < handle
    
    % Todo: 
    %   [ ] Add IsEditable? I.e is it possible to change the filename
    %   [ ] Add subfolders. I.e if session folder should be further organized in subfolders. 
    
    properties
%         DataLocations % get from folder structure
%         SubFolderOptions
%         FileTypes
%         DataAdapters
%         
%         Table

        VariableList
    end
    
    properties (Access = private)
        dataFilePath
    end
    
    methods (Static)
        
        function S = getEmptyObject()
            
            S = struct(...
                'VariableName', '', ...
                'IsDefaultVariable', false, ... 
                'FileNameExpression', '', ...
                'DataLocation', '', ...
                'FileType', '', ...
                'FileAdapter', [], ...
                'Subfolder', '');
            
        end
        
        function S = getDefaultObject(varName)
            S = nansen.setup.model.FilePathSettingsEditor.getEmptyObject;

            S.VariableName = varName;
            S.DataLocation = 'Processed';
            S.FileType = '.mat';
            
        end
    end
        
    methods
        
        function obj = FilePathSettingsEditor()
            
            obj.dataFilePath = obj.getFilePath();
             
            obj.load()
             
        end
        
        function setGlobal(obj)
            global dataFilePathModel
            dataFilePathModel = obj;
        end
        
        function save(obj)
        %save Save the list of variables to file.
        
            S.VariableList = obj.VariableList; %#ok<STRNU>
            
            if isempty(obj.dataFilePath)
                obj.dataFilePath = obj.getFilePath();
            end
            
            save(obj.dataFilePath, '-struct', 'S')
            
        end

        function load(obj)
        %load Load list (csv or xml) with required/supported variables
        
            % Load list
            if isfile(obj.dataFilePath)
                S = load(obj.dataFilePath);
                variableList = S.VariableList;
            else
                variableList = obj.initializeVariableList(); % init to empty struct
            end
            
            %variableList = obj.updateAddonList(variableList);
            
            % Assign to AddonList property
            obj.VariableList = variableList;
            
        end
        
        function refresh(obj)
            obj.dataFilePath = obj.getFilePath();
            obj.load()
        end
        
        function addEntry(obj, entry)
            
            entry = obj.validateEntry(entry);
            
            varNames = {obj.VariableList.VariableName};
            
            isMatch = strcmp(varNames, entry.VariableName);
            
            if sum(isMatch) > 1
                % Todo: Error
            elseif sum(isMatch) == 1
                existingEntry = obj.VariableList(isMatch);
                if isequal(existingEntry, entry)
                    return
                else
                    obj.VariableList(isMatch) = entry;
                    obj.save()
                    % Todo: Replace?
                end
                
            else
                obj.VariableList(end+1) = entry;
                obj.save()
            end
            
        end
        
        function removeEntry(obj)

        end
        
        function [S, isExistingEntry] = getEntry(obj, varName)
            
            varNames = {obj.VariableList.VariableName};
            isMatch = strcmp(varNames, varName);
            
            if ~any(isMatch)
                S = obj.getDefaultObject(varName);
                isExistingEntry = false;
            else
                S = obj.VariableList(isMatch);
                isExistingEntry = true;
            end
            
        end
        
        function view(obj, hParent)
            
            T = struct2table(obj.VariableList);
            disp(T)
            
        end
        
        function setVariableList(obj, S)
            % Todo: Assert that input struct is the right format
            obj.VariableList = S;
        end
    end
    
    methods (Access = private)
        function variableList = initializeVariableList(obj)

            % Initialize struct array with default fields.
            variableList = obj.getEmptyObject();
            
            variableList(1).VariableName = 'TwoPhotonSeries_Original';
            variableList(1).IsDefaultVariable = true;

            variableList(2).VariableName = 'TwoPhotonSeries_Corrected';
            variableList(2).IsDefaultVariable = true;
            variableList(2).FileNameExpression = 'two_photon_corrected';
            variableList(2).DataLocation = 'Processed';
            variableList(2).FileType = '.raw';
            variableList(2).Subfolder = 'image_registration';

            variableList(3).VariableName = 'RoiMasks';
            variableList(3).IsDefaultVariable = false;
            variableList(3).FileNameExpression = 'roi_masks';
            variableList(3).DataLocation = 'Processed';
            variableList(3).FileType = '.mat';

%             variableList(4).VariableName = 'RoiResponses_Original';
%             variableList(5).VariableName = 'RoiResponses_DfOverF';
            
        end
    end
    
    methods (Static)
        
        function pathString = getFilePath()
        %getFilePath Get filepath for loading/saving filepath settings   
            fileName = 'FilePathSettings';
            try
                pathString = nansen.config.project.ProjectManager.getProjectSubPath(fileName);
            catch
                pathString = '';
            end
        end
        
        function entry = validateEntry(entry)
            
            if isempty(entry.FileAdapter)
                % Todo: Have defaults for different filetypes...
                entry.FileAdapter = 'Default';
            end
            
        end
    end
    
    
end