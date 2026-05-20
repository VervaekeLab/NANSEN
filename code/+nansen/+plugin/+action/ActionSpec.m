classdef ActionSpec < nansen.plugin.base.PluginSpec
%ActionSpec Metadata for a NANSEN action (session/entity method) plugin.
%
%   Concrete PluginSpec subclass that adds action-specific typed properties:
%   the entity type the action targets, menu placement, execution mode, and
%   any alternative variants the action exposes as sub-items.
%
%   Sidecar JSON format (camelCase only):
%     schemaVersion   "1.0"
%     id              Stable plugin identifier
%     displayName     Human-readable name
%     implementation  { language, kind, entrypoint }
%     entityType      "session" | "roi" | ...
%     methodName      Label used in the menu
%     batchMode       "serial" | "batch"
%     isQueueable     true | false
%     alternatives    [string, ...]   (optional)
%     menuLocation    [string, ...]   (optional)
%
%   See also: nansen.plugin.base.PluginSpec, nansen.plugin.action.Registry

    properties (Constant)
        TYPE    = 'action'
        VERSION = '1.0'
        PluginType = nansen.plugin.enum.PluginType.Action
    end

    properties (Access = protected)
        RequiredProperties = ["Id", "DisplayName"]
    end

    properties
        % EntityType - Entity class this action targets (e.g. 'session').
        EntityType (1,1) string = "session"

        % MethodName - Human-readable label used for the menu item.
        MethodName (1,1) string = ""

        % BatchMode - Whether to run serially or in batch ('serial'|'batch').
        BatchMode (1,1) string = "serial"

        % IsQueueable - True when this action can be added to a task queue.
        IsQueueable (1,1) logical = true

        % Alternatives - Alternative variants exposed as sub-items.
        Alternatives (1,:) string = string.empty

        % MenuLocation - Ordered segments giving the menu path for this action.
        MenuLocation (1,:) string = string.empty
    end

    methods

        function obj = ActionSpec(options)
        %ActionSpec Construct an action spec from a property struct.
            arguments
                options (1,1) struct = struct
            end
            obj@nansen.plugin.base.PluginSpec(options)
        end

        function S = toStruct(obj)
        %toStruct Serialize to a flat camelCase struct matching the sidecar format.
            S = toStruct@nansen.plugin.base.PluginSpec(obj);
            S.entityType   = char(obj.EntityType);
            S.methodName   = char(obj.MethodName);
            S.batchMode    = char(obj.BatchMode);
            S.isQueueable  = obj.IsQueueable;
            S.alternatives = cellstr(obj.Alternatives);
            S.menuLocation = cellstr(obj.MenuLocation);
        end

        function S = toTaskAttributes(obj)
        %toTaskAttributes Build a SessionTaskMenu-compatible attribute struct.
        %
        %   Returns a struct with fields:
        %     FunctionName, FunctionHandle, TaskType, IsQueueable,
        %     BatchMode, MethodName, Alternatives, OptionsManager (class only)

            entrypoint = obj.resolveEntrypoint_();

            kind = '';
            if isstruct(obj.Implementation) && isfield(obj.Implementation, 'kind')
                kind = lower(obj.Implementation.kind);
            end

            S.FunctionName   = char(entrypoint);
            S.FunctionHandle = str2func(S.FunctionName);
            S.TaskType       = kind;
            S.IsQueueable    = obj.IsQueueable;
            S.BatchMode      = char(obj.BatchMode);
            S.MethodName     = obj.resolveMethodName_();
            S.Alternatives   = cellstr(obj.Alternatives);

            if strcmp(kind, 'class') && ~isempty(entrypoint)
                mc = meta.class.fromName(char(entrypoint));
                if ~isempty(mc)
                    isProp = strcmp({mc.PropertyList.Name}, 'OptionsManager');
                    if any(isProp)
                        S.OptionsManager = mc.PropertyList(isProp).DefaultValue;
                    end
                end
            end
        end

    end

    methods (Static)

        function specs = fromJsonFile(filePath)
        %fromJsonFile Read one or more ActionSpecs from a sidecar JSON file.
        %
        %   Handles both single-plugin sidecars and grouped-array format
        %   (top-level "plugins" array). Always returns a typed array.
            S = nansen.plugin.base.PluginSpec.readJsonFile(filePath);
            if isfield(S, 'plugins')
                specs = nansen.plugin.action.ActionSpec.empty;
                for i = 1:numel(S.plugins)
                    specs(end+1) = nansen.plugin.action.ActionSpec.fromSidecarStruct( ...
                        S.plugins(i), filePath); %#ok<AGROW>
                end
            else
                specs = nansen.plugin.action.ActionSpec.fromSidecarStruct(S, filePath);
            end
        end

        function spec = fromSidecarStruct(S, sourcePath)
        %fromSidecarStruct Build an ActionSpec from a decoded sidecar struct.
            arguments
                S          (1,1) struct
                sourcePath (1,1) string = ""
            end

            opts = struct();
            if isfield(S, 'id');             opts.Id             = string(S.id);          end
            if isfield(S, 'displayName');    opts.DisplayName    = string(S.displayName); end
            if isfield(S, 'description');    opts.Description    = string(S.description); end
            if isfield(S, 'version');        opts.PluginVersion  = string(S.version);     end
            if isfield(S, 'source');         opts.Source         = string(S.source);      end
            if isfield(S, 'provider');       opts.Provider       = S.provider;            end
            if isfield(S, 'implementation'); opts.Implementation = S.implementation;      end
            if isfield(S, 'capabilities') && ~isempty(S.capabilities)
                opts.Capabilities = string(S.capabilities);
            end
            opts.SourcePath = sourcePath;

            if isfield(S, 'entityType') && ~isempty(S.entityType)
                opts.EntityType = string(S.entityType);
            end
            if isfield(S, 'methodName') && ~isempty(S.methodName)
                opts.MethodName = string(S.methodName);
            end
            if isfield(S, 'batchMode') && ~isempty(S.batchMode)
                opts.BatchMode = string(S.batchMode);
            end
            if isfield(S, 'isQueueable')
                opts.IsQueueable = logical(S.isQueueable);
            end
            if isfield(S, 'alternatives') && ~isempty(S.alternatives)
                opts.Alternatives = string(S.alternatives(:)');
            end
            if isfield(S, 'menuLocation') && ~isempty(S.menuLocation)
                opts.MenuLocation = string(S.menuLocation(:)');
            end

            spec = nansen.plugin.action.ActionSpec(opts);
        end

    end

    methods (Access = private)

        function name = resolveEntrypoint_(obj)
        %resolveEntrypoint_ Return the MATLAB callable name from Implementation.
            name = "";
            if ~isstruct(obj.Implementation); return; end
            if isfield(obj.Implementation, 'entrypoint')
                name = string(obj.Implementation.entrypoint);
            elseif isfield(obj.Implementation, 'class')
                name = string(obj.Implementation.class);
            else
                name = obj.Id;
            end
        end

        function name = resolveMethodName_(obj)
        %resolveMethodName_ Return a non-empty MethodName, falling back to Id.
            name = char(obj.MethodName);
            if isempty(name)
                idParts = strsplit(char(obj.Id), '.');
                name = utility.string.varname2label(idParts{end});
            end
        end

    end

end
