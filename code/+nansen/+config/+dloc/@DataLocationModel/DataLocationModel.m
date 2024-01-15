classdef DataLocationModel < utility.data.StorableCatalog
%DataLocationModel Interface for detecting path of data/session folders
    
     % TODOS:
    %   [x] Combine code from getSubjectId and getSessionId into separate
    %       methods.
    
    %   Todo: when resolving disk name, need to cross check different
    %   platforms...
    
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
        VolumeInfo table
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
            
            varNames = {'Subject ID', 'Session ID', 'Experiment Date', 'Experiment Time'};
            numVars = numel(varNames);
            
            S = struct(...
                'VariableName', varNames, ...
                'SubfolderLevel', {[]}, ...
                'StringDetectMode', repmat({'ind'}, 1, numVars), ...
                'StringDetectInput', repmat({''}, 1, numVars), ...
                'StringFormat', repmat({''}, 1, numVars), ...
                'FunctionName', repmat({''}, 1, numVars) );
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
            if ~isfield(obj.Preferences, 'DefaultDataLocation')
                obj.fixDefaultDataLocation()
                dirty = true;
            end
            
            % Rootpath field changed from cell array with 2 cells to root
            % array with single to multiple cells ( remove empty cell(s) )
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
                obj.addTypeAsTableVariable()
                dirty = true;
            end
            
            % Reorder so that Type is the third table variable
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

            % Add a third variable (DiskName) to root path cell array.
            if ~isempty(obj.Data)
                if ~isfield( obj.Data(1).RootPath, 'DiskName' )
                    obj.addDiskNameToAllRootPaths()
                    dirty = true;
                end
            end

            % Add a fourth variable (DiskType) to root path cell array.
            if ~isempty(obj.Data)
                if ~isfield( obj.Data(1).RootPath, 'DiskType' )
                    obj.addDiskTypeToAllRootPaths()
                    dirty = true;
                end
            end

            for i = 1:numel(obj.Data)
                % Rename Animal to Subject
                for j = 1:numel(obj.Data(i).SubfolderStructure)
                    if strcmp( obj.Data(i).SubfolderStructure(j).Type, "Animal")
                        obj.Data(i).SubfolderStructure(j).Type = "Subject";
                        dirty = true;
                    end
                end
                % Rename Animal ID to Subject ID
                for j = 1:numel(obj.Data(i).MetaDataDef)
                    if strcmp( obj.Data(i).MetaDataDef(j).VariableName, "Animal ID")
                        obj.Data(i).MetaDataDef(j).VariableName = "Subject ID";
                        dirty = true;
                    end
                end
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
        
        function diskName = resolveDiskName(obj, rootPath)
            if ismac
                diskName = obj.resolveDiskNameMac(rootPath);
            elseif ispc
                diskName = obj.resolveDiskNamePc(rootPath);
            elseif isunix
                error('Not implemented for unix, please create github issue')
            end
        end

    end
    
    methods % Methods for updating substructs of data location
         
        function updateMetaDataDefinitions(obj, newStruct, dataLocIdx)
        %updateMetaDataDefinitions Update the metadata definition struct
        %
        %   Just replaces the struct in the MetaDataDef property with the
        %   input struct S.
                    
            oldStruct = obj.Data(dataLocIdx).MetaDataDef;
            obj.Data(dataLocIdx).MetaDataDef = newStruct;
            
            % Trigger ModelChanged event 
            evtData = uiw.event.EventData('DataLocationIndex', dataLocIdx, ...
                'SubField', 'MetadataDefiniton', 'OldData', oldStruct, ...
                'NewData', newStruct); %#ok<NASGU>

            % % % Not needed at the moment
            % % % obj.notify('DataLocationModified', evtData)
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
        
        function dataLocationStructArray = validateDataLocationPaths(obj, dataLocationStructArray)
        %validateSubfolders Validate subfolders of data locations
        %
        %   This method is used to 
        %       1) Update the root path from the model
        %       2) Ensure the file separator of subfolders is matched to
        %          the operating system

        %   % Todo: Consolidate with session/fixDataLocations
            
            if isempty(dataLocationStructArray); return; end
            
            if isa(dataLocationStructArray, 'cell')
                dataLocationStructArray = utility.struct.structcat(1, dataLocationStructArray{:});
            end
            
            if ~isfield(dataLocationStructArray, 'Subfolders'); return; end
            
            % Assume all subfolders are equal...
            
            [numItems, numDatalocations] = size(dataLocationStructArray);
            
            for i = 1:numDatalocations
                       
                dlUuid = dataLocationStructArray(1,i).Uuid;
                dlInfo = obj.getItem(dlUuid); 

                for j = 1:numItems

                    % Update the root directory from the model
                    rootUid = dataLocationStructArray(j, i).RootUid;
                    rootIdx = find( strcmp( {dlInfo.RootPath.Key}, rootUid ) );
                    
                    if ~isempty(rootIdx)
                        rootPathStr = dlInfo.RootPath(rootIdx).Value;
                        
                        if ispc
                            % Todo: % Assign correct drive letter.
                            % Check and assign correct drive letter
                        end

                        dataLocationStructArray(j, i).RootPath = rootPathStr;
                        diskName = dlInfo.RootPath(rootIdx).DiskName;
                    else
                        rootIdx = nan;
                        diskName = 'N/A';
                    end
                    dataLocationStructArray(j, i).RootIdx = rootIdx;
                    dataLocationStructArray(j, i).Diskname = diskName;
                    
                    % Make sure file separators match the file system.
                    iSubfolder = dataLocationStructArray(j,i).Subfolders;
                    if isempty(iSubfolder)
                        continue
                    elseif isunix && contains(iSubfolder, '\')              % convert file separator from unix style to windows
                        iSubfolder = strrep(iSubfolder, '\', filesep);
                    elseif ispc && contains(iSubfolder, '/')                % convert file separator from windows style to unix
                        iSubfolder = strrep(iSubfolder, '/', filesep);  
                    end
                    dataLocationStructArray(j,i).Subfolders = iSubfolder;
                end
            end
        end
        
        function updateVolumeInfo(obj, volumeInfo)
        %updateVolumeInfo Update the volume info table
            import nansen.external.fex.sysutil.listPhysicalDrives
            if nargin < 2
                volumeInfo = listPhysicalDrives();
            end
            obj.VolumeInfo = volumeInfo;
            obj.updateRootPathFromDiskName()
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
            
            oldValue = obj.Data(idx).(field);
            obj.Data(idx).(field) = value;
            
            if strcmp(field, 'Name') % Special case if name is changed
                obj.onDataLocationRenamed(dataLocationName, value)
                dataLocationName = value;
            end

            % Trigger DataLocationModified event 
            evtData = uiw.event.EventData(...
                'DataLocationName', dataLocationName, ...
                'DataField', field, ...
                'NewValue', value, ...
                'OldValue', oldValue);
            
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
    
        function substring = getSubjectID(obj, pathStr, dataLocationIndex)
        % getSubjectID - Extract subject ID from a path string
            
            if nargin < 3 || isempty(dataLocationIndex)
                dataLocationIndex = 1; 
            end

            S = obj.getMetavariableStruct('Subject ID', dataLocationIndex);
            substring = obj.getSubstringFromFolder(pathStr, S, dataLocationIndex);
        end
        
        function substring = getSessionID(obj, pathStr, dataLocationIndex)
        % getSessionID - Extract session ID from a path string
            
            if nargin < 3 || isempty(dataLocationIndex)
                dataLocationIndex = 1; 
            end

            S = obj.getMetavariableStruct('Session ID', dataLocationIndex);
            substring = obj.getSubstringFromFolder(pathStr, S, dataLocationIndex);
        end
        
        function value = getTime(obj, pathStr, dataLocationIndex)
        % getTime - Extract experiment time from a path string

            if nargin < 3 || isempty(dataLocationIndex)
                dataLocationIndex = 1; 
            end

            S = obj.getMetavariableStruct('Experiment Time', dataLocationIndex);
            substring = obj.getSubstringFromFolder(pathStr, S, dataLocationIndex);
            
            % Convert to datetime type.
            if isfield(S, 'StringFormat') && ~isempty(S.StringFormat)
                try
                    value = datetime(substring, 'InputFormat', S.StringFormat);
                    value.Format = 'HH:mm:ss'; % Format output as a time.
                catch ME
                    value = NaT;
                    warning(ME.message)
                end
            else
                value = substring;
            end
        end
        
        function value = getDate(obj, pathStr, dataLocationIndex)
        % getDate - Extract experiment date from a path string

            if nargin < 3 || isempty(dataLocationIndex)
                dataLocationIndex = 1; 
            end
            
            S = obj.getMetavariableStruct('Experiment Date', dataLocationIndex);
            substring = obj.getSubstringFromFolder(pathStr, S, dataLocationIndex);
            
            % Convert to datetime type.
            if isfield(S, 'StringFormat') && ~isempty(S.StringFormat)
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
        %       RootPath : Key, Value pair of local rootpath.
        
            % Todo: Why is this sometimes a cell?
            if isa(dlStruct, 'cell')
                dlStruct = dlStruct{1};
                warning('Data is in an unexpected format. This is not critical, but should be investigated.')
            end

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
        
        function dlStruct = reduceDataLocationInfo(~, dlStruct)
            fieldsToRemove = {'Name', 'Type', 'RootPath'};
            for i = 1:numel(fieldsToRemove)
                if isfield(dlStruct, fieldsToRemove{i})
                    dlStruct = rmfield(dlStruct, fieldsToRemove{i});
                end
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
            item = validateItem@utility.data.StorableCatalog(obj, item);
        end
        
        function S = getMetavariableStruct(obj, varName, dataLocationIdx)
        %getMetavariableStruct Get metadata struct for given variable
        %
        % Get struct containing instructions for how to find substring
        % (value of a metadata variable) from a directory path.
            
            if nargin < 3 || isempty(dataLocationIdx)
                dataLocationIdx = 1;
            end
            
            S = obj.Data(dataLocationIdx).MetaDataDef;

            % Find struct entry corresponding to requested variable
            variableIdx = strcmp({S.VariableName}, varName);
            S = S(variableIdx);
                
            % Need to know how many subfolders the data location has
            numSubfolders = numel(obj.Data(dataLocationIdx).SubfolderStructure);
            S.NumSubfolders = numSubfolders;
        end

        function substring = getSubstringFromFolder(obj, pathStr, S, dataLocationIndex)
        %getSubstringFromFolder Find substring from a pathstring.
        %
        %   substring = getSubstringFromFolder(obj, pathStr, varName) Get a
        %   substring containing the value of a variable given by varName.
        %   The substring is obtained from the given pathStr based on
        %   instructions from the DataLocationModel's MetaDataDef property.
        
            % Initialize output
            substring = '';
            dataLocationName = obj.Data(dataLocationIndex).Name;

            mode = S.StringDetectMode;

            if strcmp(mode, 'func')
                substring = feval(S.FunctionName, pathStr, dataLocationName);
                if strcmp(substring, 'N/A'); substring = ''; end
                return
            end

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

            S.Data = obj.updateRootPathFromDiskName(S.Data);
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
        %
        %   Reference can refer to the local settings for root paths or the
        %   original ones. 
        %
        %   This method updates the rootpath struct based on the reference.
        %   If mode is mirror, the struct is copied, otherwise, the
        %   diskname is only copied if the disktype is local.
        %
        %   This is in order to be able to switch between drives that
        %   should be equal across different systems and drives that should
        %   not (i.e local drives)
        
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
                            
                            if isfield(iTarget.RootPath, 'DiskType')
                                % Do nothing, this should always be kept
                                % based on the current selection.
                            end

                            if isfield(iSource.RootPath, 'DiskName')
                                if isfield(iTarget.RootPath, 'DiskType') && ...
                                        strcmp(iTarget.RootPath(keyIdx).DiskType, 'Local')
                                    iTarget.RootPath(keyIdx).DiskName = iSource.RootPath(jKey).DiskName;
                                end
                            end
                        end
                    end
                    
                    target(targetIdx) = iTarget;
                end
            end
        end
        
        function S = updateRootPathFromDiskName(obj, S)
        %updateRootPathFromDiskName Ensure path matches diskname for root 
        %
        %   On windows, drive mounts for external drives are dynamic, and a
        %   drive might be mounted with different letter from time to time.
        %   Here the root path is updated based on the name of the disk and
        %   the current letter assignment of that disk (if it is present)

            if nargin < 2
                S = obj.Data;
            end

            if ispc
                volumeInfo = nansen.external.fex.sysutil.listPhysicalDrives();
                
                for i = 1:numel(S) % Loop through DataLocations
                    if ~isfield(S(i), 'RootPath')
                        continue
                    end

                    if ~isfield(S(i).RootPath, 'DiskName')
                        S(i).RootPath = obj.addDiskNameToRootPathStruct(S(i).RootPath);
                    end

                    for j = 1:numel(S(i).RootPath) % Loop through root folders
                        jDiskName = S(i).RootPath(j).DiskName;
                        
                        % If not assigned previously, diskName defaults to
                        % an empty double, but here, change it to a string.
                        if isempty(jDiskName) && isa(jDiskName, 'double')
                            jDiskName = "";
                        end

                        isMatch = volumeInfo.VolumeName == jDiskName;
                        
                        if any(isMatch)
                            if sum(isMatch) > 1
                                warning('Multiple disks have the same name (%s)', jDiskName);
                            end
                            diskLetter = volumeInfo.DeviceID(isMatch);
                        else
                            diskLetter = sprintf('%d:', j);
                        end
                        
                        % Todo: Remove:
                        % Replace symbol that was meant to indicate drive
                        % is not connected, which turned out to be
                        % troublesome:
                        if strncmp(S(i).RootPath(j).Value, '~', 1)
                            S(i).RootPath(j).Value(1)=num2str(i);
                        end
                         
                        platformName = obj.pathIsWhichPlatform(S(i).RootPath(j).Value);
                        conversion = [platformName, '2', 'pc'];

                        try
                            updatedPath = obj.replaceDiskMountInPath(S(i).RootPath(j).Value, diskLetter, conversion);
                        catch
                            updatedPath = S(i).RootPath(j).Value;
                        end
                        S(i).RootPath(j).Value = updatedPath;

                        if ~isfolder( S(i).RootPath(j).Value )
                            %warning('Root not available')
                        end
                    end
                end
            else
                % Pass
                % Todo: root path was created in windows
            end

            if nargin < 2
                obj.Data = S;
                if ~nargout
                    clear S
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
 
    methods (Access = private) % Internal
        % Todo: these should not be methods of this class
        function diskName = resolveDiskNamePc(obj, rootPath)
        %resolveDiskName Resolve disk name given disk letter
            
            if isempty(obj.VolumeInfo)
                obj.updateVolumeInfo()
            end
            
            diskLetter = string(regexp(rootPath, '.*:', 'match'));
            try
                matchedIdx = find( obj.VolumeInfo.DeviceID == diskLetter );
            catch 
                matchedIdx = [];
            end
            if ~isempty(matchedIdx)
                diskName = obj.VolumeInfo.VolumeName(matchedIdx);
            else
                diskName = '';
            end
        end

        function diskName = resolveDiskNameMac(obj, rootPath)
            splitPath = strsplit(rootPath, '/');
            matchedIdx = find( strcmp(splitPath, 'Volumes') ) + 1;
            if ~isempty(matchedIdx)
                diskName = splitPath{matchedIdx};
            else
                diskName = '';
            end
        end
        
    end
   
    methods %(Access = ?nansen.config.project.Project)
        
        function onProjectRenamed(obj, oldName, newName)
        % onProjectRenamed - Rename configs that depend on project name
        
        % Note: Function names for extracting data identifiers 
        % (subjectId, sessionId, experimentData & experimentTime) depend on
        % the project name
        
            for i = 1:obj.NumDataLocations
                for j = 1:numel(obj.Data(i).MetaDataDef)
                    if isfield(obj.Data(i).MetaDataDef(j), 'FunctionName')
                        oldFunctionName = obj.Data(i).MetaDataDef(j).FunctionName;
                        if ~isempty(oldFunctionName)
                            newFunctionName = strrep(oldFunctionName, oldName, newName);
                            obj.Data(i).MetaDataDef(j).FunctionName = newFunctionName;
                        end
                    end
                end
            end
            obj.save()
        end
        
    end

    methods (Static)
        
        function pathString = getDefaultFilePath()
        %getFilePath Get filepath for loading/saving datalocation settings
        
            error('NANSEN:DefaultDataLocationNotImplemented', ...
                ['Please specify a file path for a data location model. ' ...
                'There is currently no default data location model.'])
        end
        
        function platformName = pathIsWhichPlatform(pathStr)
        %pathIsWhichPlatform Determine platform which a path is native to
            
            % Todo: get pattern for unix from preferences?

            platformNameList = {'mac', 'pc', 'unix'};
            strPattern = {'^/Volumes', '^\w{1}\:', '^n/a'};
            
            for i = 1:numel(platformNameList)
                if ~isempty(regexp(pathStr, strPattern{i}, 'match'))
                    platformName = platformNameList{i}; 
                    return
                end
            end
            platformName = 'N/A';
        end
        
        function pathStr = replaceDiskMountInPath(pathStr, mount, conversionType)
            
           switch conversionType
                case 'mac2pc'
                    splitPath = strsplit(pathStr, '/');
                    oldStr = ['/', strjoin(splitPath(2:3), '/')];
                    %oldStr = regexp(pathStr, '^/Volumes/.*/', 'match'); %todo...
                    newStr = char(mount);

                case 'mac2mac'
                    splitPath = strsplit(pathStr, '/');
                    oldStr = splitPath{3};
                    newStr = mount;
                    
                case 'pc2mac'
                    oldStr = regexp(currentRoot, '^\w{1}\:', 'match', 'once');
                    newStr = sprintf('/Volumes/%s', mount);
                   
                case 'pc2pc'
                    oldStr = pathStr(1:2);
                    newStr = char(mount); 
           end
           
           pathStr = char( strrep(pathStr, oldStr, newStr) );
          
           switch conversionType
               case 'mac2pc'
                   pathStr = strrep(pathStr, '/', '\');
               case 'pc2mac'
                   pathStr = strrep(pathStr, '\', '/');
           end
        end
    end

    %%  Temporary methods for fixing various introduced changes
    %
    %   The remaining methods of this class should be deprecated. They have
    %   been added when necessary to make sure that things kept working as
    %   this class and the DataLocation concept has evolved.

    methods (Access = private)

        function fixDefaultDataLocation(obj)

            % Todo: Add uuid, not name

            if obj.NumDataLocations == 1
                obj.DefaultDataLocation = obj.Data(1).Name;
            elseif obj.NumDataLocations > 1
                obj.Data(2).Type = nansen.config.dloc.DataLocationType('PROCESSED');
                obj.DefaultDataLocation = obj.Data(2).Name;
            end
        end

        function addTypeAsTableVariable(obj)
            fieldNamesOld = fieldnames(obj.Data);
            for i = 1:numel(obj.Data)
                obj.Data(i).Type = 'recorded';
            end
            
            obj.Data = orderfields(obj.Data, ...
                [fieldNamesOld(1:2); 'Type'; fieldNamesOld(3:end)]);
        end
    
        function addDiskNameToAllRootPaths(obj)
            for i = 1:numel(obj.Data)
                obj.Data(i).RootPath = obj.addDiskNameToRootPathStruct(obj.Data(i).RootPath);
            end
        end

        function rootPathStruct = addDiskNameToRootPathStruct(obj, rootPathStruct)
            for i = 1:numel(rootPathStruct)
                rootPathStruct(i).DiskName = ...
                    obj.resolveDiskName(rootPathStruct(i).Value);
            end
        end

        function addDiskTypeToAllRootPaths(obj)
            for i = 1:numel(obj.Data)
                for j = 1:numel(obj.Data(i).RootPath)
                    obj.Data(i).RootPath(j).DiskType = 'External';
                end
            end
        end
    end
    
    methods (Static)
        
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
                            sNew(j).Diskname = '';
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
