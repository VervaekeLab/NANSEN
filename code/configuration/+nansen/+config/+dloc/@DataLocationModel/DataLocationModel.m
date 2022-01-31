classdef DataLocationModel < utility.data.TabularArchive
%DataLocationModel Interface for detecting path of data/session folders
    

    % TODOS:
    %   [x] Combine code from getSubjectId and getSessionId into separate
    %       methods.
    
    % QUESTIONS:
    
    properties (Constant, Access = protected)
        ITEM_TYPE = 'Data Location'
    end
    
    properties (Dependent, SetAccess = private)
        DataLocationNames
        NumDataLocations
    end
    
    properties (Dependent)
        DefaultDataLocation
    end
    
    events
        DataLocationAdded
        DataLocationModified
        DataLocationRemoved
    end
    
    methods (Static) % Methods in separate files
        S = getEmptyItem()
        
        S = getDefaultItem()
    end

    methods (Static)
        
%         function S = getEmptyObject()
%             
%             import nansen.config.dloc.DataLocationModel
%             
%             S = struct;
%             
%             S.Name = '';
%             S.RootPath = {'', ''};
%             S.ExamplePath = '';
%             S.DataSubfolders = {};
% 
%             S.SubfolderStructure = DataLocationModel.getDefaultSubfolderStructure();
%             S.MetaDataDef = DataLocationModel.getDefaultMetadataStructure();
%         end

        function S = getDefaultMetadataStructure()
            
            varNames = {'Animal ID', 'Session ID', 'Experiment Date', 'Experiment Time'};
            %varNames = {'Animal ID', 'Session ID'};
            numVars = numel(varNames);
            
            S = struct(...
                'VariableName', varNames, ...
                'SubfolderLevel', {[]}, ...
                'StringDetectMode', repmat({'ind'}, 1, numVars), ...
                'StringDetectInput', repmat({''}, 1, numVars), ...
                'StringFormat', repmat({''}, 1, numVars));
        end
        
        function S = getDefaultSubfolderStructure()
        %getDefaultSubfolderStructure Create a default struct
            S = struct(...
                'Name', '', ...
                'Type', '', ...
                'Expression', '', ...
                'IgnoreList', {{}} );
        end
        
    end
    
    methods % Constructor 
        function obj = DataLocationModel(varargin)
            
            obj@utility.data.TabularArchive(varargin{:})
            
            if isempty(obj.FilePath)
                obj.FilePath = obj.getDefaultFilePath();
            end
            
            obj.load()
            
            obj.tempDevFix()
        end
        
        function tempDevFix(obj)
            
            if ~isfield(obj.Preferences, 'DefaultDataLocation')
                if obj.NumDataLocations == 1
                    obj.DefaultDataLocation = obj.Data(1).Name;
                else
                    obj.DefaultDataLocation = obj.Data(2).Name;
                end
            end
            
            for i = 1:numel(obj.Data)
                
                rootPath = obj.Data(i).RootPath;
                
                if any(strcmp(rootPath, ''))
                    rootPath(strcmp(rootPath, '')) = [];
                end
                
                obj.Data(i).RootPath = rootPath;
            end
            
            obj.save()
        end
    end
    
    methods % Set/get methods
    
        function numDataLocations = get.NumDataLocations(obj)
            numDataLocations = numel(obj.Data);
        end
        
        function dataLocationNames = get.DataLocationNames(obj)
            dataLocationNames = obj.ItemNames;
        end
        
        function defaultDataLocation = get.DefaultDataLocation(obj)
            
            defaultDataLocation = obj.Preferences.DefaultDataLocation;
            
        end
        
        function set.DefaultDataLocation(obj, newValue)
            
            assert(ischar(newValue), 'Please provide a character vector with the name of a data location')
            
            message = sprintf('"%s" can not be a default data location because no data location with this name exists.', newValue);
            assert(any(strcmp(obj.DataLocationNames, newValue)), message)
            
            obj.Preferences.DefaultDataLocation = newValue;
            
        end
        
    end
    
    methods
        
        function setGlobal(obj)
            global dataLocationModel
            dataLocationModel = obj;
        end
        
        function validateRootPath(obj, dataLocIdx)
            
            % Todo: Loop through all entries in cell array (if many are present) 
            
            thisDataLoc = obj.Data(dataLocIdx);
            if ~isfolder(thisDataLoc.RootPath{1})
                thisName = obj.Data(dataLocIdx).Name;
                error('Root path for DataLocation "%s" does not exist', thisName)
            end
            
        end
        
        function createRootPath(obj, dataLocIdx)
            thisRootPath = obj.Data(dataLocIdx).RootPath{1};
            if ~isfolder(thisRootPath)
                mkdir(thisRootPath)
                fprintf('Created root directory for DataLocation %s', obj.Data(dataLocIdx).Name)
            end
        end
        
    end
    
    methods % Methods for updating substructs of data location
         
        function updateMetaDataDefinitions(obj, newStruct)
        %updateMetaDataDefinitions Update the metadata definition struct
        %
        %   Just replaces the struct in the MetaDataDef property with the
        %   input struct S.
        
            dataLocIdx = 1;
            
            oldStruct = obj.Data(dataLocIdx).MetaDataDef;
            obj.Data(dataLocIdx).MetaDataDef = newStruct;
            
            % Trigger ModelChanged event 
            evtData = uiw.event.EventData('DataLocationIndex', dataLocIdx, ...
                'SubField', 'MetadataDefiniton', 'OldData', oldStruct, ...
                'NewData', newStruct);
            
%             obj.notify('DataLocationModified', evtData)
            
        end
        
        function updateSubfolderStructure(obj, newStruct, idx)
        %updateSubfolderStructure Update the SubfolderStructure struct
        %
        %   Just replaces the struct in the SubfolderStructure property 
        %   with the input struct S.
        
            if nargin < 3
                idx = 1;
            end
            
            dataLocationName = obj.Data(idx).Name;
            
            obj.modifyDataLocation(dataLocationName, ...
                'SubfolderStructure', newStruct)
            
            
            %oldStruct = obj.Data(idx).SubfolderStructure;
            %obj.Data(idx).SubfolderStructure = newStruct;
            
            % Update example path
            subFolderNames = {newStruct.Name};
            obj.Data(idx).ExamplePath = fullfile(obj.Data(idx).RootPath{1}, subFolderNames{:});
            
% %             % Trigger ModelChanged event 
% %             evtData = uiw.event.EventData('DataLocationIndex', idx, ...
% %                 'SubField', 'SubfolderStructure', 'OldData', oldStruct, ...
% %                 'NewData', newStruct);
% %             
% %             obj.notify('DataLocationModified', evtData)
            
        end
        
    end
    
    methods % Methods for accessing/modifying items
        
        function addDataLocation(obj, newDataLocation)
        %addDataLocation Add data location item to data
        
            if isempty(newDataLocation.Name)
                newDataLocation.Name = obj.getNewName();
            end
            
            obj.insertItem(newDataLocation)
            
            % Trigger DataLocationAdded event 
            evtData = uiw.event.EventData(...
                'NewValue', newDataLocation);
            obj.notify('DataLocationAdded', evtData)
        end
        
        function removeDataLocation(obj, dataLocationName)
        %removeDataLocation Remove data location item from data
            
            % Todo: Necessary if a undo operation is implemented...
            %oldValue = obj.getItem(dataLocationName);
            
            [~, idx] = obj.containsItem(dataLocationName);
            
            obj.removeItem(dataLocationName)
            
            % Trigger ModelChanged event 
            evtData = uiw.event.EventData(...
                'DataLocationIndex', idx, ...
                'DataLocationName', dataLocationName);
            obj.notify('DataLocationRemoved', evtData)
        end
        
        function modifyDataLocation(obj, dataLocationName, field, value)
        %modifyDataLocation Change data field of DataLocation
        %
        %   modifyDataLocation(obj, dataLocationName, field, value)
        %   modifies a field of the Data property of the model.
        %   dataLocationName is the name of the data location to modify. If
        %   the modification is on the name itself, the dataLocationName
        %   should be the current (old) name.
        
        
            [tf, idx] = obj.containsItem(dataLocationName);
            
            if ~any(tf)
                error('DataLocation with name "%s" does not exist', dataLocationName)
            end
            
            obj.Data(idx).(field) = value;
            
            if strcmp(field, 'Name') % Special case if name is change
                obj.onDataLocationRenamed(dataLocationName, value)
                dataLocationName = value;
            end
                        
            % Trigger DataLocationModified event 
            evtData = uiw.event.EventData(...
                'DataLocationName', dataLocationName, ...
                'DataField', field, ...
                'NewValue', value);
            
            obj.notify('DataLocationModified', evtData)
            
        end
        
        function S = getDataLocation(obj, dataLocationName)
            S = obj.getItem(dataLocationName);
        end
        
        function pathStr = getExampleFolderPath(obj, dataLocationName)
            
            dataLocation = obj.getItem(dataLocationName);
            pathStr = dataLocation.ExamplePath;
            
        end
       
    end
    
    methods % Methods for getting data descriptions from filepaths
        
        function substring = getSubjectID(obj, pathStr)
            % Todo: Specify index as well....
            
            S = obj.getMetavariableStruct('Animal ID');
            substring = obj.getSubstringFromFolder(pathStr, S);

        end
        
        function substring = getSessionID(obj, pathStr)
            
            S = obj.getMetavariableStruct('Session ID');
            substring = obj.getSubstringFromFolder(pathStr, S);
            
            % If no substring is retrieved, used the foldername of the last
            % folder in the pathstring.
            if isempty(substring)
                [~, substring] = fileparts(pathStr);
            end

        end
        
        function value = getTime(obj, pathStr)
            
            S = obj.getMetavariableStruct('Experiment Time');
            substring = obj.getSubstringFromFolder(pathStr, S);
            
            % Convert to datetime type.
            if ~isempty(substring) && isfield(S, 'StringFormat') && ~isempty(S.StringFormat)
                value = datetime(substring, 'InputFormat', S.StringFormat);
                value.Format = 'HH:mm:ss'; % Format output as a time.
            else
                value = substring;
            end
        end
        
        function value = getDate(obj, pathStr)
            
            S = obj.getMetavariableStruct('Experiment Date');
            substring = obj.getSubstringFromFolder(pathStr, S);
            
            % Convert to datetime type.
            if ~isempty(substring) && isfield(S, 'StringFormat') && ~isempty(S.StringFormat)
                value = datetime(substring, 'InputFormat', S.StringFormat);
            else
                value = substring;
            end
            
        end
        
    end
    
    methods (Access = ?nansen.config.dloc.DataLocationModelApp)
        
        function restore(obj, data)
            obj.Data = data;
            obj.save()
        end
        
    end
    
    methods (Access = protected)
        
        function item = validateItem(obj, item)
            % Todo...
            item = item;
        end
        
        function S = getMetavariableStruct(obj, varName)
        %getMetavariableStruct Get metadata struct for given variable
        %
        % Get struct containing instructions for how to find substring
        % (value of a metadata variable) from a directory path.
            
            dataLocIdx = 1;
            S = obj.Data(dataLocIdx).MetaDataDef;

            % Find struct entry corresponding to requested variable
            variableIdx = strcmp({S.VariableName}, varName);
            S = S(variableIdx);
                
            % Need to know how many subfolders the data location has
            numSubfolders = numel(obj.Data(dataLocIdx).SubfolderStructure);
            S.NumSubfolders = numSubfolders;

        end

        function substring = getSubstringFromFolder(obj, pathStr, S)
        %getSubstringFromFolder Find substring from a pathstring.
        %
        %   substring = getSubstringFromFolder(obj, pathStr, varName) Get a
        %   substring containing the value of a variable given by varName.
        %   The substring is obtained from the given pathStr based on
        %   instructions from the DataLocationModel's MetaDataDef property.
        
        % Initialize output
            substring = '';

            mode = S.StringDetectMode;
            strPattern = S.StringDetectInput;
            folderLevel = S.SubfolderLevel;
            
            % Abort if instructions are not present.
            if isempty(strPattern) || isempty(folderLevel)
                return;    
            end
            
            % Get the index of the folder containing the substring,
            % counting backward from the deepest subfolder level.
            reversedFolderIdx = S.NumSubfolders - folderLevel;
            
            folderNames = strsplit(pathStr, filesep);
            folderName = folderNames{end-reversedFolderIdx}; % Unpack from cell array
            
            % Get the substring using either indexing or regular
            % expressions.
            try
                switch lower(mode)

                    case 'ind'
                        %substring = folderName(strPattern);
                        substring = eval( ['folderName([' strPattern '])'] );
                        
                    case 'expr'
                        substring = regexp(folderName, strPattern, 'match', 'once');
                end
            catch
                substring = '';
            end
            
        end
        
        function name = getNewName(obj)
            
            prefix = 'UNNAMED';
            
            isUnnamed = contains(obj.ItemNames, prefix);
            numUnnamed = sum(isUnnamed);
            unnamedNames = sort(obj.ItemNames(isUnnamed));
            
            candidates = arrayfun(@(i) sprintf('%s_%d', prefix, i), ...
                1:(numUnnamed+1), 'uni', 0);
            
            % Find candidate which is not in use...
            candidates = setdiff(candidates, unnamedNames, 'stable');
            
            name = candidates{1};
            
        end
    end
    
    methods (Access = private)
        function onDataLocationRenamed(obj, oldName, newName)
                           
            obj.assignItemNames()
            
            % Update value default data location if this was the one that
            % was renamed..
            if strcmp(obj.DefaultDataLocation, oldName)
                obj.DefaultDataLocation = newName;
            end
            
        end
    end
    
    methods (Hidden, Access = protected) 
        
    end
    
    methods (Static)
        
        function pathString = getDefaultFilePath()
        %getFilePath Get filepath for loading/saving datalocation settings   
            fileName = 'DataLocationSettings';
            try
                pathString = nansen.config.project.ProjectManager.getFilePath(fileName);
            catch
                pathString = '';
            end
        end
        
    end
    
end

