classdef SessionData < dynamicprops & matlab.mixin.CustomDisplay & applify.mixin.UserSettings
% SessionData - Provides lazy access to data variables of a Session object

% NOTE:
% Each data variable is exposed as a dynamic property whose get-method
% loads the data through the shared nansen.cache.DataCache on first access.
% Display does not go through the get-methods: getPropertyGroups supplies the
% values it shows directly (peeked, never loaded), so rendering a SessionData
% never reads data from disk.

% Todo:
%   [ ] Remove all methods that are duplicates from the session class.
%   [ ] Improve display for non-scalar object. Header and property groups

    properties (Constant, Hidden)
        USE_DEFAULT_SETTINGS = false;
        DEFAULT_SETTINGS = nansen.session.SessionData.getDefaultSettings()
    end

    properties
        sessionID
    end

    properties (Dependent, Hidden)
        IsInitialized
    end

    properties (Access = private)
        SessionObject
        DataLocationModel
        DataVariableModel
    end

    properties (Access = private)
        State (1,1) string {mustBeMember(State, ["initialized", "uninitialized"])} = "uninitialized"
        VariableList struct
        FileList containers.Map
        OnDemandLabel = categorical({'<on demand>'})
    end

    properties (Access = private, Dependent)
        VariableNames
    end

    methods (Hidden) % Constructor
        function obj = SessionData(sessionObj)

            obj.SessionObject = sessionObj;

            % Inherit properties for sessionObj. Todo: Avoid duplication...
            obj.sessionID = sessionObj.sessionID;

            % Initialize the property value here (because Map is handle)
            obj.FileList = containers.Map;
        end
    end

    methods
        function obj = initialize(obj)
        %initialize Initialize the variables of session
            fprintf('Initializing session data variables...\n')
            obj.updateDataVariables();
        end

        function obj = update(obj)
            fprintf('Updating session data variables...\n')
            obj.updateDataVariables();
        end

        function varNames = getVariableNames(obj)
            varNames = obj.VariableNames;
        end

        function resetCache(obj, varNames)

            cache = nansen.cache.DataCache.instance();

            if nargin < 2
                % Drop every cached variable belonging to this session.
                cache.removeByPrefix( obj.getCacheKeyPrefix() );
                return
            end

            if isa(varNames, 'char')
                varNames = {varNames};
            end

            for i = 1:numel(varNames)
                cache.remove( obj.getCacheKey(varNames{i}) );
            end
        end
    end

    methods % Set/get methods
        function dlModel = get.DataLocationModel(obj)
            dlModel = obj.SessionObject.DataLocationModel;
        end

        function varNames = get.VariableNames(obj)
            if isempty(obj.VariableList)
                varNames = {};
            else
                varNames = {obj.VariableList.VariableName};
            end
        end

        function tf = get.IsInitialized(obj)
            if obj.State == "uninitialized"
                tf = false;
            elseif obj.State == "initialized"
                tf = true;
            end
        end
    end

    methods (Hidden)

        function obj = showInternalVariables(obj)
            obj.settings.ShowInternalVariables = true;
        end

        function obj = hideInternalVariables(obj)
            obj.settings.ShowInternalVariables = false;
        end

        function obj = showFavouriteVariables(obj)
            obj.settings.ShowFavouriteVariables = true;
        end

        function obj = hideFavouriteVariables(obj)
            obj.settings.ShowFavouriteVariables = false;
        end

        function obj = showDefaultVariables(obj)
            obj.settings.ShowDefaultVariables = true;
        end

        function obj = hideDefaultVariables(obj)
            obj.settings.ShowDefaultVariables = false;
        end

        function obj = showUserVariables(obj)
            obj.settings.ShowUserVariables = true;
        end

        function obj = hideUserVariables(obj)
            obj.settings.ShowUserVariables = false;
        end

        function updateDataVariables(obj)

            if isempty(obj.SessionObject.DataLocationModel)
                % Todo: Consider to throw an error.
                fprintf('Aborted, this session does not have a DataLocationModel')
                return
            end

            obj.DataVariableModel = nansen.VariableModel();
            varNames = {obj.DataVariableModel.Data.VariableName};

            for i = 1:numel(varNames)
                try
                    filePath = obj.SessionObject.getDataFilePath(varNames{i});

                    if isfile(filePath)
                        if ~isprop(obj, varNames{i})
                            obj.addDataProperty(varNames{i})
                            obj.appendToVariableList(obj.DataVariableModel.Data(i))
                        end
                    end
                catch
                    % Todo: Find if session folder is not found, otherwise
                    % need to do something...
                end
            end

            obj.State = "initialized";
        end

        function varNames = getDataType(obj, typeName, mustExist)
        %getDataType Get variable names for specified data type

            if nargin < 3; mustExist = true; end

            % Todo: get from session object:
            % dataVariableModel = obj.SessionObject.VariableModel;
            dataVariableModel = nansen.VariableModel();
            fileAdapters = {dataVariableModel.Data.FileAdapter};

            switch typeName
                case {'RoiGroup', 'RoiArray', 'roiArray'}
                    tf = strcmp(fileAdapters, 'RoiGroup') | strcmp(fileAdapters, 'RoiArray');
                    varNames = {dataVariableModel.Data(tf).VariableName};

                otherwise
                    tf = strcmp(fileAdapters, typeName);
                    varNames = {dataVariableModel.Data(tf).VariableName};
            end

            if mustExist
                tf = false(1, numel(varNames));
                for i = 1:numel(varNames)
                    tf(i) = isprop(obj, varNames{i} );
                end
            else
                tf = true(1, numel(varNames));
            end

            varNames = varNames(tf);
        end

        function varNames = uiSelectVariableName(obj, dataType, selectionMode)
        %uiSelectVariableName Open dialog to select variable from sdata
        % ------------------------------------------------------------------
        %
        %   SYNTAX:
        %
        %   varNames = obj.uiSelectVariableName() opens a dialog to select
        %   one or more variables that are available on the SessionData object
        %
        %   varNames = obj.uiSelectVariableName(dataType) lets user select
        %   among variables from the specified dataType
        %
        %   varNames = obj.uiSelectVariableName(dataType, selectionMode)
        %   additionally determines the selection mode. selectionMode can
        %   be 'multi' (Default) or 'single'.
        %
        %   OUTPUT:
        %       varNames : cell array of variable name(s)

            arguments
                obj nansen.session.SessionData
                dataType (1,1) string = ""
                selectionMode (1,1) string {mustBeMember(selectionMode, ["single", "multiple"])} = "multiple"
            end

            if dataType == ""
                varNames = obj.VariableNames;
            else
                varNames = obj.getDataType(char(dataType));
            end

            if isempty(varNames)
                if exist('dataType', 'var')
                    error('NANSEN:SessionData:VariableOfTypeNotAvailable', ...
                        'No variables are available for data type "%s"', dataType)
                else
                    error('NANSEN:SessionData:NoVariablesAvailable', ...
                        'No data variables are available for this session.')
                end
            end

            msg = 'Select a data variable:';
            [selectedIndex, tf] = listdlg('ListString', varNames, ...
                'PromptString', msg, 'SelectionMode', selectionMode);

            if tf
                varNames = varNames(selectedIndex);
            else
                varNames = {};
            end
        end

        function variableName = uiSetVariableName(obj, dataType)

            if nargin < 2
                varNames = obj.VariableNames;
            else
                varNames = obj.getDataType(dataType, false);
            end

            nameLabel = 'data variable name';

            variableName = uics.inputOrSelect(varNames, 'Title', ...
                'Set Variablename', 'ItemName', nameLabel);
        end

        function saveType(obj, typeName, data, varargin)

            variableName = obj.uiSetVariableName(typeName);

            if isempty(variableName); return; end

            obj.getDataFilePath(variableName, '-w', varargin{:});
            obj.saveData(variableName, data)
            obj.updateDataVariables();
        end
    end

    methods (Access = protected)
        function addDataProperty(obj, variableName)
            % The actual data lives in the shared nansen.cache.DataCache, so
            % no private backing property is needed here. The get-method is a
            % display-safe read (it never triggers a load).
            pPublic = obj.addprop(variableName);
            pPublic.GetMethod = @(h) obj.getDataVariable(variableName);
            pPublic.SetAccess = 'private'; % todo: Add set functionality
        end

        function appendToVariableList(obj, variableItem)
            if isempty(obj.VariableList)
                obj.VariableList = variableItem;
            else
                obj.VariableList(end+1) = variableItem;
            end
        end

        function key = getCacheKey(obj, varName)
        %getCacheKey Cache key for one of this session's data variables
            key = nansen.cache.DataCache.buildKey( ...
                "session", string(obj.sessionID), string(varName));
        end

        function prefix = getCacheKeyPrefix(obj)
        %getCacheKeyPrefix Key prefix matching all of this session's variables
            prefix = "session:" + string(obj.sessionID) + ":";
        end

        function value = getDataVariable(obj, varName)
        %getDataVariable Load (if needed) and return a variable's data
        %
        %   This is the get-method for each data-variable dynamic property,
        %   so a plain obj.<variable> reference loads the data through the
        %   shared cache. Display does not call this method (see
        %   getPropertyGroups), so rendering the object never loads data.
            value = nansen.cache.DataCache.instance().getOrLoad( ...
                obj.getCacheKey(varName), @() obj.loadData(varName));
        end

        function setDataVariable(~, varargin)
            error('NANSEN:SessionData:SetDataVariableNotImplemented', ...
                'Setting data variables is not implemented.')
        end

        function str = getHeader(obj)
            str = getHeader@matlab.mixin.CustomDisplay(obj);

            className = strrep(class(obj), 'nansen.session.', '');

            if numel(obj) == 1
                if obj.State == "uninitialized"
                    className = sprintf('%s (%s)', className, obj.State);
                end
            end

            str = strrep(str, '>SessionData<', sprintf('>%s<', className));

            if numel(obj) == 1
                str = strrep(str, 'properties', 'data variables');
            else
                str = strrep(str, 'with properties:', '(variables not displayable for non-scalar SessionData)');
            end

            % Todo: Improve header for arrays
        end

        function propGroup = getPropertyGroups(obj)

            % Initialize output variable as empty
            propGroup = matlab.mixin.util.PropertyGroup.empty;

            if numel(obj) > 1
                return
                % Todo: Improve property groups for arrays!
            end

            % Nothing to show until variables are registered. Variables are
            % only ever added during initialization, so a populated
            % VariableList already implies the object is initialized.
            if isempty(obj(1).VariableList)
                return;
            end

            isInternal = [obj(1).VariableList.IsInternal];
            isFavorite = [obj(1).VariableList.IsFavorite];
            isCustom = [obj(1).VariableList.IsCustom];
            isPreset = ~isCustom;

            propGroup = matlab.mixin.util.PropertyGroup.empty;

            % Each group is built from a name->value struct rather than a list
            % of property names. Supplying values directly stops CustomDisplay
            % from invoking the data-variable get-methods, so rendering the
            % object never loads data; unloaded variables show the on-demand
            % placeholder instead.
            if obj.settings.ShowFavouriteVariables && any(isFavorite)
                propGroup = [propGroup, obj.buildVariableGroup(isFavorite, 'Favorite Variables:')];
            end

            if obj.settings.ShowDefaultVariables && any(isPreset)
                propGroup = [propGroup, obj.buildVariableGroup(isPreset, 'Default Variables:')];
            end

            if obj.settings.ShowUserVariables && any(isCustom)
                propGroup = [propGroup, obj.buildVariableGroup(isCustom, 'User Variables:')];
            end

            if obj.settings.ShowInternalVariables && any(isInternal)
                propGroup = [propGroup, obj.buildVariableGroup(isInternal, 'Internal Variables:')];
            end
        end

        function group = buildVariableGroup(obj, isMember, title)
        %buildVariableGroup PropertyGroup of name->value for a variable subset
        %
        %   Values are peeked from the shared cache, never loaded: a loaded
        %   variable shows its value and an unloaded one shows the on-demand
        %   placeholder, all without touching disk.

            cache = nansen.cache.DataCache.instance();
            propNames = sort( {obj.VariableList(isMember).VariableName} );

            values = struct();
            for i = 1:numel(propNames)
                values.(propNames{i}) = ...
                    cache.peek(obj.getCacheKey(propNames{i}), obj.OnDemandLabel);
            end

            group = matlab.mixin.util.PropertyGroup(values, title);
        end

        function onSettingsChanged(obj, name, value) %#ok<INUSD>
            % Pass
        end
    end

    methods (Sealed, Hidden)
        function T = addprop(obj, varargin)
            T = addprop@dynamicprops(obj, varargin{:});
            if ~nargout; clear T; end
        end
    end

    methods (Access = protected) % Load data variables
        function data = loadData(obj, varName, varargin)
            data = obj.SessionObject.loadData(varName, varargin{:});
        end

        function saveData(obj, varName, data, varargin)
            obj.SessionObject.saveData(varName, data, varargin{:});
        end

        function pathStr = getDataFilePath(obj, varName, varargin)
        %getDataFilePath Get filepath to data within a session folder
        %
        %   pathStr = sessionObj.getDataFilePath(varName) returns a
        %   filepath (pathStr) for data with the given variable name
        %   (varName).
        %
        %   pathStr = sessionObj.getDataFilePath(varName, mode) returns the
        %   filepath subject to the specified MODE:
        %       '-r'    : Get filepath of existing file (Default)
        %       '-w'    : Get filepath of existing file or create filepath
        %
        %   pathStr = sessionObj.getDataFilePath(__, Name, Value) uses
        %   name-value pair arguments to control aspects of the filename.
        %
        %   PARAMETERS:
        %
        %       Subfolder : If file is in a subfolder of sessionfolder.
        %
        %
        %   EXAMPLES:
        %
        %       pathStr = sObj.getFilePath('dff', '-w', 'Subfolder', 'roisignals')

            % Todo:
            %   [v] (Why) do I need mode here? If -w, variable is added to
            %       model
            %   [ ] Implement load/save differences, and default datapath
            %       for variable names that are not defined.
            %   [ ] Implement ways to grab data spread over multiple files, i.e
            %       if files are separate by imaging channel, imaging plane,
            %       trials or are just split into multiple parts...

            pathStr = obj.SessionObject.getDataFilePath(varName, varargin{:});
        end
    end

    methods (Static)
        function S = getDefaultSettings()

            S = struct;
            S.ShowDefaultVariables = true;
            S.ShowUserVariables = true;
            S.ShowInternalVariables = false;
            S.ShowFavouriteVariables = true;
        end
    end
end
