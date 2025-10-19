classdef VariableModel < utility.data.StorableCatalog %& utility.data.mixin.CatalogWithBackup
 
% Categories
%   Preset / Custom
%   Internal / Public?
%   Favorites

    % Todo:
    %   [x] Add subfolders. I.e if session folder should be further organized in subfolders.
    %   [ ] Methods for above...
    %
    %   [ ] Should internal variables be custom or preset? Preset...
    %   [ ] Flag for whether model data has changed...
    %   [ ] Add event for case where variable item is modified
    
    properties (Constant)
%         FileTypes
%         DataAdapters
    end
    
    properties (Constant, Hidden)
        ITEM_TYPE = 'Variable'
    end
    
    properties (Dependent, SetAccess = private)
        VariableNames
        NumVariables
    end
    
    properties (Access = private)
        DoNotify = true
        DataLocationNameChangedListener
        %DataLocationModel % Todo: needed?
    end
    
    events
        DataLocationNameChanged
        VariableAdded
        VariableRemoved
    end
    
    methods (Static) % Get empty and default item
        
        function S = getBlankItem()
            
            S = struct(...
                'VariableName', '', ...         % Name of variable
                'DataLocation', '', ...         % todo: rename DataLocationName? Name of datalocation where variable is stored.
                'DataLocationUuid', '', ...     % uuid of datalocation variable belongs to (internal)
                'Subfolder', '', ...            % Subfolder within sessionfolder where variable is saved to file (optional)
                'FileNameExpression', '', ...   % Part of filename to reckognize variable from (optional)
                'FileType', '', ...             % File type of variable
                'FileAdapter', '', ...          % File adapter to use for loading and saving variable
                'DataType', '', ...             % Datatype of variable: Will depend on file adapter
                'Alias', '', ...                % alias or "nickname" for variables
                'GroupName', '', ...            % Placeholder...
                'IsCustom', false, ...          % Is variable custom, i.e user made?
                'IsInternal', false, ...        % Flag for internal variables
                'IsFavorite', false, ...        % Flag for favorited variables
                'PathInFile', '');              % Path for variable in file if it is located within a container file, like .mat or .h5
        end
        
        function S = getDefaultItem(varName)
        % getDefaultItem -  Get default data variable configuration struct
        %
        %   A default variable configuration will use the default file
        %   adapter (i.e mat files) and it is Custom by default.
            S = nansen.config.varmodel.VariableModel.getBlankItem();

            S.VariableName = varName;
            S.DataLocation = '';
            S.FileType = '.mat';
            S.FileAdapter = 'Default';
            S.IsCustom = true;
        end
    end
        
    methods % Constructor
        
        function obj = VariableModel(varargin)

            % Superclass constructor. Loads given (or default) archive
            obj@utility.data.StorableCatalog(varargin{:})
            
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
        
        function addDataLocationModel(obj, dataLocationModel)
            
            el = listener(dataLocationModel, 'DataLocationModified', ...
                @obj.onDataLocationModelModified);
            obj.DataLocationNameChangedListener = el;
        end
        
        function [S, isExistingEntry] = getVariableStructure(obj, varName)
            
            S = obj.getItem(varName);
            
            % Check if varname exists as alias:
            if isempty(S)
                S = obj.getVariableInfoFromField(varName, 'Alias');
            end
            
            % Check if varname exists as filename:
            if isempty(S)
                S = obj.getVariableInfoFromField(varName, 'FileNameExpression');
            end
            
            isExistingEntry = ~isempty(S);
            
            % Create a default variable structure
            if ~isExistingEntry
                S = obj.getDefaultItem(varName);
                S.IsCustom = true;
            end

            % Check if subfolder uses different fileseparator than current
            if contains(S.Subfolder, '/') && ~strcmp('/', filesep)
                S.Subfolder = strrep(S.Subfolder, '/', filesep);
            end
            if contains(S.Subfolder, '\') && ~strcmp('\', filesep)
                S.Subfolder = strrep(S.Subfolder, '\', filesep);
            end
        end
        
        function load(obj)
        %load Load list (csv or xml) with required/supported variables
            obj.tempFixVariableNameInFile()
            load@utility.data.StorableCatalog(obj)
        end
        
        function view(obj)
            T = struct2table(obj.Data);
            disp(T)
        end

        function updateDefaultValues(obj)
            
            str = 'Not implemented yet';
            
            hasDataLocationUuid = isfield(obj.Data, 'DataLocationUuid');
            if ~hasDataLocationUuid
                dlModel = nansen.DataLocationModel();
            end
            
            fileAdapterList = nansen.dataio.listFileAdapters();
            
            for i = 1:numel(obj.Data)
                if isempty( obj.Data(i).FileAdapter ) || strcmp(obj.Data(i).FileAdapter, str)
                    obj.Data(i).FileAdapter = 'Default';
                end
                
                if ~hasDataLocationUuid
                    dlName = obj.Data(i).DataLocation;
                    dlItem = dlModel.getDataLocation(dlName);
                    obj.Data(i).DataLocationUuid = dlItem.Uuid;
                end
            end
            
            if ~isfield(obj.Data, 'DataType')
                [obj.Data(:).DataType] = deal('');
                for i = 1:numel(obj.Data)
                    if ~strcmp(obj.Data(i).FileAdapter, 'Default')
                        isMatch = strcmp({fileAdapterList.FileAdapterName}, obj.Data(i).FileAdapter);
                        if any(isMatch)
                            fileAdapterFcn = str2func(fileAdapterList(isMatch).FunctionName);
                            obj.Data(i).DataType = fileAdapterFcn().DataType;
                        else
                            % pass
                        end
                    end
                end
            end
            
            if ~isfield(obj.Data, 'Alias')
                [obj.Data(:).Alias] = deal('');
            end
            
            if ~isfield(obj.Data, 'GroupName')
                [obj.Data(:).GroupName] = deal('');
            end
            
            if ~isfield(obj.Data, 'IsCustom')
                [obj.Data(:).IsCustom] = deal(false);
            end
            
            if ~isfield(obj.Data, 'IsInternal')
                [obj.Data(:).IsInternal] = deal(false);
            end
            
            if ~isfield(obj.Data, 'IsFavorite')
                [obj.Data(:).IsFavorite] = deal(false);
            end
                       
            if ~isfield(obj.Data, 'PathInFile')
                [obj.Data(:).PathInFile] = deal('');
            end
        end
        
        % % Variable interaction and utility methods

        function varName = findVariableByFilename(obj, filePath, mode)

            arguments
                obj
                filePath
                mode (1,1) string {mustBeMember(mode, ["first", "all"])} = "first"
            end
            
            [~, filename, ext] = fileparts(filePath);

            filenameExpressions = {obj.Data.FileNameExpression};
            fileTypes = {obj.Data.FileType};
            
            isEmpty = cellfun(@isempty, filenameExpressions);
            matchesFiletype = strcmp(fileTypes, ext);
            matchesFilename = cellfun(@(expr) contains(filename, expr), filenameExpressions);

            % Find the longest match
            matchedFilenameExpressions = filenameExpressions(matchesFilename);
            matchLength = cellfun(@numel, matchedFilenameExpressions);
            maxLength = max(matchLength);
            matchedFilenameExpressions = unique( matchedFilenameExpressions(matchLength == maxLength) );
            
            % Refine match by only the longest matches
            matchesFilename = cellfun(@(expr) ...
                any(strcmp(matchedFilenameExpressions, expr)), ...
                filenameExpressions, 'UniformOutput', true);
            
            isMatch = matchesFiletype & matchesFilename & ~isEmpty;

            warnMultiple = false;
            if ~any(isMatch)
                isMatch = matchesFiletype;
                if sum(isMatch) == 1
                    matchedIdx = find(isMatch);
                else
                    matchedIdx = [];
                end

            elseif sum(isMatch) > 1
                if mode == "first"
                    matchedIdx = find(isMatch, 1, 'first');
                    warnMultiple = true;
                else
                    matchedIdx = find(isMatch);
                end
            else
                matchedIdx = find(isMatch);
            end
            
            if ~isempty(matchedIdx)
                varName = {obj.Data(matchedIdx).VariableName};
                if warnMultiple
                    warning('Multiple matching variables were detected, selected first one (%s)', varName{1})
                end
            else
                varName = '';
            end

            if isscalar(varName)
                varName = varName{1};
            end
        end

        function fileAdapter = getFileAdapter(obj, variableName)
            [filePath, variableInfo] = obj.getDataFilePath(variableName);
            fileAdapterFcn = obj.getFileAdapterFcn(variableInfo);
            fileAdapter = fileAdapterFcn(filePath);
        end

        function fileAdapterFcn = getFileAdapterFcn(obj, variableInfo)
        %getFileAdapterFcn Get function handle for creating file adapter

            fileAdapterList = nansen.dataio.listFileAdapters();

            if ischar(variableInfo)
                [~, variableInfo] = obj.getDataFilePath(variableInfo);
            end
            
            % Find file adapter match for name
            isMatch = strcmp({fileAdapterList.FileAdapterName}, variableInfo.FileAdapter);
            
            if ~any(isMatch)
                error('File adapter was not found')
            elseif sum(isMatch) > 1
                error('This is a bug. Please report')
            end
            
            fileAdapterFcn = str2func(fileAdapterList(isMatch).FunctionName);
        end
    
        function varNames = getVariableNamesOfType(obj, typeName)
        %getVariableNamesOfType Get name of variables of specified datatype
        %
        %   Syntax:
        %       varNames = obj.getVariableNamesOfType(typeName) returns a
        %       cell array of variable names. The variable names represent
        %       all the variables in the model of the specified datatype
        %       iven by typeName
        %
        %   Input arguments:
        %       typeName - A character vector or a string of a data type.
        %           Note: This is case sensitive. Todo: Should it be?
        %
        %   Output arguments:
        %       varNames - A cell array of character vectors. If no
        %       variables were found for the given type, the cell array
        %       contains one element, 'N/A'. Todo: Return empty cell array?
    
            allDataTypes = {obj.Data.DataType};
            isOfGivenType = strcmp(allDataTypes, typeName);
            varNames = {obj.Data(isOfGivenType).VariableName};
        end
    
        function addDataVariableSet(obj, variableList)
        % addDataVariableSet - Add a set of variables to the variable model
        %
        %   Inputs:
        %       variableList - variableList is a struct array of variable
        %       configurations

            if isempty(variableList); return; end

            dataLocationModel = nansen.DataLocationModel(); % dependent prop?
            defaultDataLocation = dataLocationModel.getDefaultDataLocation;
            
            % Insert variable specifications to the model
            for j = 1:numel(variableList)
                thisName = variableList(j).VariableName;

                if ~any(obj.containsItem(thisName))
                    if useDefaultDataLocation(variableList(j).DataLocation)     % Local function
                        variableList(j).DataLocation = defaultDataLocation.Name;
                        variableList(j).DataLocationUuid = defaultDataLocation.Uuid;
                    end

                    obj.insertItem(variableList(j));
                end
            end
            obj.save()
        end

        function removeDataVariableSet(obj, variableList)
        % removeDataVariables - Remove a set of data variables
        %
        %   Inputs:
        %       variableList - variableList is a string array of names
        %           of variables to remove

        %   Note: This is most likely not going to be used. User should
        %   instead remove variables individually.

        %   Todo:
        %       [ ] backup items that are removed...

            for i = 1:numel(variableList)
                thisName = variableList(i);

                if any(obj.containsItem(thisName))
                    obj.removeItem(thisName)
                end
            end
            obj.save()
        end
    
        function data = getVariableSet(obj, flag)
            
            if nargin < 2 || isempty(flag)
                flag = 'public';
            end
            
            flag = validatestring(flag, {'all', 'public', 'internal'}, 1);
            
            keep = true(size(obj.Data));

            if strcmp(flag, 'all')
                % Keep all
            elseif strcmp(flag, 'public')
                keep = keep & ~[obj.Data.IsInternal];
            elseif strcmp(flag, 'internal')
                keep = keep & [obj.Data.IsInternal];
            end
        
            data = obj.Data(keep);
        end
    end
    
    methods % Todo: Move to nansen.dataio.DataVariable
        function fileName = lookForFile(obj, folderPath, variableInfo, options)

            % Todo: Add FEX:recursiveDir as dependency and ensure the
            % following works:
            % % nvPairs = {...
            % %     "FileType", S.FileType, ...
            % %     "Expression", S.FileNameExpression ...
            % %     };
            % %
            % % L = recursiveDir(sessionFolder, nvPairs{:});
            
            arguments
                obj
                folderPath (1,1) string
                variableInfo
                options.FilterFcn = []
            end

            if isa(variableInfo, 'char')
                variableInfo = obj.getVariableStructure(variableInfo);
            end

            fileType = variableInfo.FileType;

            if ~strncmp(fileType, '.', 1)
                fileType = ['.', fileType];
            end

            expression = obj.patternToWildcardExpression(variableInfo.FileNameExpression, fileType);
            
            L = dir(fullfile(folderPath, expression));
            L = L(~strncmp({L.name}, '.', 1));

            if ~isempty(options.FilterFcn)
                L = L(options.FilterFcn({L.name}));
            end
            
            if ~isempty(L) && numel(L)==1
                fileName = L.name;
            elseif ~isempty(L) && numel(L)>1
                fileName = L(1).name;
                warning off backtrace
                warning('Multiple files were found for variable "%s".\nSelected first file in list.', variableInfo.VariableName)
                warning on backtrace
            else
                fileName = '';
            end
        end

        function wildCardExpression = patternToWildcardExpression(obj, filenamePattern, fileExtension)
            
            arguments
                obj (1,1) nansen.config.varmodel.VariableModel %#ok<INUSA>
                filenamePattern (1,1) string
                fileExtension (1,1) string = missing
            end

            wildCardExpression = filenamePattern;

            if startsWith(wildCardExpression, "^")
                wildCardExpression = extractAfter(wildCardExpression, "^");
            else
                if ~startsWith(wildCardExpression, '*')
                    wildCardExpression = "*" + wildCardExpression;
                end
            end

            if endsWith(wildCardExpression, '$')
                wildCardExpression = extractBefore(wildCardExpression, '$');
            else
                if ~ismissing(fileExtension) && ~endsWith(wildCardExpression, fileExtension)
                    wildCardExpression = wildCardExpression + "*" + fileExtension; % Todo: '*' + expression + '*' + fileType <- Is this necessary???
                elseif ~endsWith(wildCardExpression, '*')
                    wildCardExpression = wildCardExpression + "*";
                end
            end

            while contains(wildCardExpression, '**') % Ensure we dont have doubles
                wildCardExpression = strrep(wildCardExpression, '**', '*');
            end
        end
    end

    methods % Override superclass methods
        function newItem = insertItem(obj, newItem)
            import nansen.config.varmodel.event.VariableAddedEventData
            newItem = obj.updateVariableDataType(newItem);
            newItem = insertItem@utility.data.StorableCatalog(obj, newItem);
            
            if obj.DoNotify
                eventData = VariableAddedEventData(newItem);
                obj.notify('VariableAdded', eventData)
            end

            if ~nargout
                clear newItem
            end
        end

        function removeItem(obj, itemName)
            import nansen.config.varmodel.event.VariableRemovedEventData
            removeItem@utility.data.StorableCatalog(obj, itemName);
            
            if obj.DoNotify
                eventData = VariableRemovedEventData(itemName);
                obj.notify('VariableRemoved', eventData)
            end
        end
    end

    methods (Hidden, Access = {?nansen.config.varmodel.VariableModelApp, ?nansen.app.setup.SetupWizard})
        function setVariableList(obj, S)
            obj.Data = S;
        end
    end
    
    methods (Access = protected)
        
        function item = validateItem(obj, item)
            item = validateItem@utility.data.StorableCatalog(obj, item);
            if isempty(item.FileAdapter)
                % Todo: Have defaults for different filetypes...
                item.FileAdapter = 'Default';
            end
            
            if strcmp(item.DataLocation, 'DEFAULT')
                dataLocationModel = nansen.DataLocationModel();
                item.DataLocation = dataLocationModel.DefaultDataLocation;
            end
        end
    end
    
    methods (Access = private)
        
        function S = getVariableInfoFromField(obj, varName, fieldName)
        %getVariableInfoFromField Get variable info from fieldname of Data
            S = struct.empty;
            
            names = {obj.Data.(fieldName)};
            isMatch = strcmp(names, varName);
            
            if any(isMatch) && sum(isMatch) == 1
                S = obj.Data(isMatch);
            elseif any(isMatch) && sum(isMatch) > 1
                %warning('Found multiple matched variables, selected to first')
                isMatch = find(isMatch, 1, 'first');
                S = obj.Data(isMatch);
            end
        end
        
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
        
        function onDataLocationModelModified(obj, src, evt)
            
            if strcmp(evt.DataField, 'Name')
                newName = evt.NewValue;
                dataLocationItem = src.getDataLocation(newName);
                
                obj.updateVariableDataLocation(dataLocationItem)
            end
        end
        
        function updateVariableDataLocation(obj, dataLocationItem)
        %updateVariableDataLocation Update datalocation name for variables
        %
        %   This method is used to make sure the datalocation name is
        %   up-to-date with the name of the data location model
            
            %isDirty = false;
        
            dlUuid = dataLocationItem.Uuid;
            dlName = dataLocationItem.Name;
            
            for i = 1:numel(obj.Data)
                if strcmp( obj.Data(i).DataLocationUuid, dlUuid )
                    obj.Data(i).DataLocation = dlName;
                    %isDirty = true;
                end
            end
            
            evtData = event.EventData;
            obj.notify('DataLocationNameChanged', evtData);
        end
    end
    
    methods (Access = ?nansen.config.varmodel.VariableModelUI)
        function enableNotifications(obj)
            obj.DoNotify = true;
        end

        function disableNotifications(obj)
            obj.DoNotify = false;
        end
    end

    methods (Static)
        
        function pathString = getDefaultFilePath()
        %getDefaultFilePath Get filepath for loading/saving filepath settings
           
            error('NANSEN:DefaultVariableModelNotImplemented', ...
                ['Please specify a file path for a file variable model. ' ...
                'There is currently no implementation of a default model.'])
        end
    end
    
    methods (Static)
        
        function className = getFileAdapterFunctionName(fileAdapterName)
            % Todo: This step should not be necessary...
            switch fileAdapterName
                case 'ImageStack'
                    className = 'nansen.stack.ImageStack';
            end
        end
    end

    methods (Static) % Todo: Should be moved to a data variable class
        function variableItem = updateVariableDataType(variableItem)
            fileAdapterList = nansen.dataio.listFileAdapters();
            if ~strcmp(variableItem.FileAdapter, 'Default')
                isMatch = strcmp({fileAdapterList.FileAdapterName}, variableItem.FileAdapter);
                if any(isMatch)
                    fileAdapterFcn = str2func(fileAdapterList(isMatch).FunctionName);
                    variableItem.DataType = fileAdapterFcn().DataType;
                else
                    % pass
                end
            end
        end
    end
end

% Local utility functions
function tf = useDefaultDataLocation(dataLocationName)
    tf = strcmp(dataLocationName, 'DEFAULT') || isempty(dataLocationName);
end
