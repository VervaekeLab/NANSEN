classdef FunctionAction < handle
%FunctionAction Runtime wrapper for sidecar-defined function-based actions.
%
%   Provides a uniform invocation surface for action plugins whose
%   implementation.kind is 'function' or 'function-set'. Analogous to
%   nansen.plugin.fileadapter.FunctionFileAdapter for the file-adapter type.
%
%   Usage:
%     spec    = registry.resolve('my.action.id');
%     action  = nansen.plugin.action.FunctionAction(spec);
%     action.run(sessionObject)
%
%   See also: nansen.plugin.action.ActionSpec, nansen.plugin.action.Registry

    properties (SetAccess = private)
        % Spec - The ActionSpec this wrapper was constructed from.
        Spec nansen.plugin.action.ActionSpec
    end

    properties (Access = private)
        FunctionHandle function_handle
    end

    methods

        function obj = FunctionAction(spec)
        %FunctionAction Construct a wrapper from an ActionSpec.
            arguments
                spec (1,1) nansen.plugin.action.ActionSpec
            end
            obj.Spec = spec;
            obj.FunctionHandle = obj.resolveFunction(spec);
        end

        function run(obj, entityObject, varargin)
        %run Invoke the wrapped action function.
        %
        %   run(obj, entityObject)
        %   run(obj, entityObject, Name, Value, ...)
            obj.FunctionHandle(entityObject, varargin{:});
        end

        function attrs = getTaskAttributes(obj)
        %getTaskAttributes Return a SessionTaskMenu-compatible attribute struct.
            attrs = obj.Spec.toTaskAttributes();
        end

    end

    methods (Static, Access = private)

        function fcn = resolveFunction(spec)
        %resolveFunction Resolve the implementation function from the spec.
            if ~isstruct(spec.Implementation)
                error('nansen:plugin:action:FunctionAction:MissingImplementation', ...
                    'ActionSpec "%s" has no implementation struct.', char(spec.Id))
            end
            if isfield(spec.Implementation, 'entrypoint')
                name = spec.Implementation.entrypoint;
            elseif isfield(spec.Implementation, 'function')
                name = spec.Implementation.function;
            else
                error('nansen:plugin:action:FunctionAction:MissingEntrypoint', ...
                    'ActionSpec "%s" has no entrypoint in implementation.', char(spec.Id))
            end
            fcn = str2func(char(name));
        end

    end

end
