classdef DataLocationModel < utility.data.StorableCatalog
%DataLocationModel Interface for detecting path of data/session folders
    

    % TODOS:
    %   [x] Combine code from getSubjectId and getSessionId into separate
    %       methods.
    
    % QUESTIONS:
    
    properties (Constant, Hidden)
        ITEM_TYPE = 'Data Location'
    end
    
    properties (Dependent, SetAccess = private)
        DataLocationNames
        NumDataLocations
    end
    
    properties (Dependent)
        IsDirty % Todo: Dependent on whether data bakcup is different than data
        DefaultDataLocation
    end
    
    properties (Access = private)
        DataBackup % Todo: assign this on construction and when model is marked as clean(?)
        RootPathListOriginal % Original rootpaths. Will be replaced with root-paths of local computer on load.
    end
    
    events
        DataLocationAdded
        DataLocationModified
        DataLocationRemoved
    end
    
    methods (Static) % Methods in separate files
        %S = getEmptyItem()
        
        S = getBlankItem()
        
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
            
            % Superclass constructor. Loads given (or default) archive 
            obj@utility.data.StorableCatalog(varargin{:})
            
            obj.tempDevFix()
        end
        
        function tempDevFix(obj)
            
            dirty = false;
            
            % Add default data location to preferences
            % Todo: Add uuid, not name
            if ~isfield(obj.Preferences, 'DefaultDataLocation')
                if obj.NumDataLocations == 1
                    obj.DefaultDataLocation = obj.Data(1).Name;
                elseif obj.NumDataLocations > 1
                    obj.Data(2).Type = nansen.config.dloc.DataLocationType('PROCESSED');
                    obj.DefaultDataLocation = obj.Data(2).Name;
                end
                
                dirty = true;
            end
            
            % Rootpath field changed from cell array with 2 cells to root
            % array with 1 to many cells ( remove empty cell(s) ) 
            for i = 1:numel(obj.Data)
                
                rootPath = obj.Data(i).RootPath;
                
                if any(strcmp(rootPath, ''))
                    rootPath(strcmp(rootPath, '')) = [];
                    dirty = true;
                end
                
                obj.Data(i).RootPath = rootPath;
            end
            
            % Add 'Type' as a table variable on the third column
            if ~isfield(obj.Data, 'Type')
                fieldNamesOld = fieldnames(obj.Data);
                for i = 1:numel(obj.Data)
                    obj.Data(i).Type = 'recorded';
                end
                
                obj.Data = orderfields(obj.Data, ...
                    [fieldNamesOld(1:2); 'Type'; fieldNamesOld(3:end)]);
                dirty = true;
            end
            
            fieldNames = fieldnames(obj.Data);
            if ~strcmp(fieldNames{3}, 'Type')
                fieldNamesNew = setdiff(fieldNames, 'Type', 'stable');
                
                obj.Data = orderfields(obj.Data, ...
                    [fieldNamesNew(1:2); 'Type'; fieldNamesNew(3:end)]);
                
                dirty = true;
            end
            
            if ~isfield(obj.Preferences, 'SourceID')
                obj.Preferences.SourceID = utility.system.getComputerName(true);
                dirty = true;
            end
            
            if dirty
                obj.save()
            end
            
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
            
            if isempty(obj.Data); defaultDataLocation = ''; return; end
            
            dataLocationUuid = obj.Preferences.DefaultDataLocation;
            defaultDataLocation = obj.getNameFromUuid(dataLocationUuid);
            
        end
        
        function set.DefaultDataLocation(obj, newValue)
            
            assert(ischar(newValue), 'Please provide a character vector with the name of a data location')
            
            % Check if data location with given name exists...
            message = sprintf('"%s" can not be a default data location because no data location with this name exists.', newValue);
            assert(any(strcmp(obj.DataLocationNames, newValue)), message)
            
            % Check if data location is allowed to be a default data location.
            dataLocationItem = obj.getDataLocation(newValue);
            message = sprintf('"%s" can not be a default data location because the data location is of type "%s".', newValue, dataLocationItem.Type.Name);
            assert(dataLocationItem.Type.AllowAsDefault, message)
            
            dataLocationUuid = dataLocationItem.Uuid;
            
            obj.Preferences.DefaultDataLocation = dataLocationUuid;
            
        end
        
    end
    
    methods % Modify save/load to include local settings...
        
% %         function load(obj)
% %             
% %             load@utility.data.StorableCatalog(obj)
% %             
% %         end
% %         
% %         function save(obj)
% %             
% %         end
% %         
        
    end
    
    methods
        
        function setGlobal(obj)
            global dataLocationModel
            dataLocationModel = obj;
        end
        
        function validateRootPath(obj, dataLocIdx)
        %validateRootPath Check if root path exists
        
            % Todo: Loop through all entries in cell array (if many are present) 

            thisDataLoc = obj.Data(dataLocIdx);
            if ~isfolder(thisDataLoc.RootPath(1).Value)
                thisName = obj.Data(dataLocIdx).Name;
                error('Root path for DataLocation "%s" does not exist', thisName)
            end
            
        end
        
        function createRootPath(obj, dataLocIdx, rootIdx)
            
            if nargin < 3; rootIdx = 1; end
            thisRootPath = obj.Data(dataLocIdx).RootPath(rootIdx).Value;
            
            if ~isfolder(thisRootPath)
                mkdir(thisRootPath)
                fprintf('Created root directory for DataLocation %s\n', obj.Data(dataLocIdx).Name)
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
            
            if ~isempty(obj.Data(idx).RootPath)
                obj.Data(idx).ExamplePath = ...
                    fullfile(obj.Data(idx).RootPath(1).Value, subFolderNames{:});
            end
            
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
            
            newDataLocation = obj.insertItem(newDataLocation);
            
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
            
            % Todo: Unset default data location if this was the default
            % data location
            
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
            
            % Make sure data location type is one of the type enumeration
            % members:
            if strcmp(field, 'Type') && ischar(value)
                value = nansen.config.dloc.DataLocationType(value);
                % Todo: Make sure default datalocation is still allowed type: 
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
        
        function dataLocationItem = getDefaultDataLocation(obj)
        %getDefaultDataLocation Get the default datalocation item
            dataLocationName = obj.DefaultDataLocation;
            dataLocationItem = obj.getDataLocation(dataLocationName);
        end
        
        function S = getDataLocation(obj, dataLocationName)
        %getDataLocation Get datalocation item by name
            S = obj.getItem(dataLocationName);
        end
        
        function pathStr = getExampleFolderPath(obj, dataLocationName)
            
            dataLocation = obj.getItem(dataLocationName);
            pathStr = dataLocation.ExamplePath;
            
        end
       
    end
    
    methods % Methods for getting data descriptions from filepaths
    % Todo: all these methods should be outsourced. THis is more like a 
    % table variable domain..
    
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
    
    methods % Utility methods
        
        function dlStruct = expandDataLocationInfo(obj, dlStruct)
        %expandDataLocation Expand information of data location structure
        %
        %   dlStruct = dlm_obj.expandDataLocationInfo(dlStruct) add the
        %   following fields to a data location structure:
        %       Name : Name of datalocation
        %       Type : Datalocation type
        %       RootPath : Key,Value pair of local rootpath.
        
            for iDl = 1:numel(dlStruct) %obj.NumDataLocations

                dlUuid = dlStruct(iDl).Uuid;
                
                thisDlItem = obj.getItem(dlUuid);

                % Add name and type fields
                fields = {'Name', 'Type'};
                for k = 1:numel(fields)
                    dlStruct(iDl).(fields{k}) = thisDlItem.(fields{k});
                end

                % Add rootpath field
                rootUid = dlStruct(iDl).RootUid;
                rootIdx = find( strcmp( {thisDlItem.RootPath.Key}, rootUid ));

                if ~isempty(rootIdx)
                    dlStruct(iDl).RootPath = thisDlItem.RootPath(rootIdx).Value;
                end
            end
        end
        
        function dlStruct = reduceDataLocationInfo(obj, dlStruct)
            
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
            item = validateItem@utility.data.StorableCatalog(obj, item);
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
    
    methods (Access = protected) % Override superclass methods
        
        function S = cleanStructOnSave(obj, S)
        %cleanStructOnSave DataLocationModel specific changes when saving

            for i = 1:numel(S.Data)
                S.Data(i).Type = S.Data(i).Type.Name;
            end
            
            % Export local paths and restore original paths.
            S = obj.exportLocalRootPaths(S);

        end
        
        function S = modifyStructOnLoad(obj, S)
        %modifyStructOnLoad DataLocationModel specific changes when loading
        %

            % Create type object instance.
            for i = 1:numel(S.Data)
                if ~isfield(S.Data(i), 'Type') || isempty(S.Data(i).Type)
                    S.Data(i).Type = nansen.config.dloc.DataLocationType('recorded');
                else
                    S.Data(i).Type = nansen.config.dloc.DataLocationType(S.Data(i).Type);
                end
            end
            
            if ~isfield(S.Preferences, 'SourceID')
                S.Preferences.SourceID = utility.system.getComputerName(true);
            end
            
            S = obj.updateRootPathDataType(S); % Todo_ temp: remove before release
            
            % Get local root paths...
            S = obj.importLocalRootPaths(S);
            
        end
        
        
        function filePath = getLocalRootPathSettingsFile(obj)
            
            import nansen.config.project.ProjectManager
            dirPath = ProjectManager.getProjectPath('current', 'local');
            
            fileName = 'datalocation_local_rootpath_settings.mat';
            filePath = fullfile(dirPath, fileName);
            
        end
        
        
        function S = importLocalRootPaths(obj, S)
            
            % Load local settings for datalocation model root paths and 
            % replace those that are in the struct S with the local ones.
            
            % Keep the originals stored in the RootPathListOriginal
            % property.

            filePath = obj.getLocalRootPathSettingsFile();
            
            %obj.RootPathListOriginal = struct;
            n = numel(S.Data);
            [obj.RootPathListOriginal(1:n).Uuid] = S.Data.Uuid;
            [obj.RootPathListOriginal(1:n).RootPath] = S.Data.RootPath;
            
            % Todo: Can not just replace, what if root paths were
            % created somewhere else since last session. Loop through those
            % data locations and rootkeys that values exist for...
            
            computerID = utility.system.getComputerName(true);
            isSource = isequal(S.Preferences.SourceID, computerID);
            
            if isfile(filePath) && ~isSource
                S_ = load(filePath);
                reference = S_.RootPathListLocal;
                S.Data = obj.updateRootPathFromReference(S.Data, reference);
            end
            
        end
        
        function S = exportLocalRootPaths(obj, S)
            
            % Save the local root paths and restore the originals in the
            % datalocation model.

            % Restore original root path list
            computerID = utility.system.getComputerName(true);
            if ~isequal(S.Preferences.SourceID, computerID)
                
                % 1) Save current root path list to local file
                n = numel(S.Data);
                [S_.RootPathListLocal(1:n).Uuid] = S.Data.Uuid;
                [S_.RootPathListLocal(1:n).RootPath] = S.Data.RootPath;

                filePath = obj.getLocalRootPathSettingsFile();
                save(filePath, '-struct', 'S_')

                % 2) Restore originals 
                reference = obj.RootPathListOriginal; % struct array
                S.Data = obj.updateRootPathFromReference(S.Data, reference);

            end
        end
        
        function target = updateRootPathFromReference(obj, target, source)
        %updateRootPathFromReference Update rootpath struct from reference
        
            for iDloc = 1:numel(source)

                thisUuid = source(iDloc).Uuid;
                targetIdx = find(strcmp( {target.Uuid}, thisUuid));

                if ~isempty(targetIdx) % Original rootpath list must exist

                    iSource = source(iDloc);
                    iTarget = target(targetIdx);
                    
                    referenceKeys = {iSource.RootPath.Key};

                    for jKey = 1:numel(referenceKeys)

                        thisKey = iSource.RootPath(jKey).Key;
                        keyIdx = find(strcmp( {iTarget.RootPath.Key}, thisKey ));
                        
                        if isempty(keyIdx)
                            continue; 
                        else
                            iTarget.RootPath(keyIdx).Value = iSource.RootPath(jKey).Value;
                        end

                    end
                    
                    target(targetIdx) = iTarget;
                end
            end
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
        
        
        function S = updateRootPathDataType(S) % TEMP: Todo: remove
        %updateRootPathDataType 
            
            % Todo: Should we make struct array instead, with key value
            % fields and use universal unique ids????
        
            % Update root data type from cell array to struct.
            if numel(S.Data) > 0
                if isa(S.Data(1).RootPath, 'cell')
                    for i = 1:numel(S.Data)
                        
                        sNew = struct();
                        for j = 1:numel(S.Data(i).RootPath)
                            sNew(j).Key = nansen.util.getuuid();
                            sNew(j).Value = S.Data(i).RootPath{j};
                        end
                        
                        S.Data(i).RootPath = sNew;
                    end
                    
                elseif isa(S.Data(1).RootPath, 'struct') && ~isfield(S.Data(1).RootPath, 'Key')
                    for i = 1:numel(S.Data)
                        rootKeys = fieldnames(S.Data(i).RootPath);
                        rootPaths = struct2cell( S.Data(i).RootPath );
                        S.Data(i).RootPath = struct;
                        n = numel(rootKeys);
                        [S.Data(i).RootPath(1:n).Key] = rootKeys;
                        [S.Data(i).RootPath(1:n).Value] = rootPaths;
                    end
                elseif isa(S.Data(1).RootPath, 'struct') && isempty(S.Data(1).RootPath)
                    return
                    
                elseif isa(S.Data(1).RootPath, 'struct') && isfield(S.Data(1).RootPath, 'Key') && isa(S.Data(1).RootPath(1).Key, 'cell')
                    for i = 1:numel(S.Data)
                        S.Data(i).RootPath(1).Key = nansen.util.getuuid();
                        S.Data(i).RootPath(1).Value = S.Data(i).RootPath(1).Value{1};
                    end
                    
                    
                end
            end
        end
        
    end
    
end

