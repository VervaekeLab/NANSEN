classdef TestSpec < nansen.plugin.base.PluginSpec
%TestSpec Minimal concrete PluginSpec used in Phase 1 foundation tests.
%
%   This class exists solely for unit testing. It must not be used in
%   production code.

    properties (Constant)
        TYPE    = 'test'
        VERSION = '1.0'
        PluginType = nansen.plugin.enum.PluginType.FileAdapter
    end

    properties (Access = protected)
        RequiredProperties = ["Id", "DisplayName"]  % No validator: inherited from Specification abstract
    end

    properties
        % TestTag - extra field for round-trip verification
        TestTag (1,1) string = ""
    end

    methods

        function S = toStruct(obj)
        %toStruct Extend base sidecar struct with TestSpec-specific field.
            S = toStruct@nansen.plugin.base.PluginSpec(obj);
            S.testTag = obj.TestTag;
        end
    end

    methods (Static)

        function specs = fromJsonFile(filePath)
        %fromJsonFile Read one or more TestSpec instances from a JSON sidecar.
            S = nansen.plugin.base.PluginSpec.readJsonFile(filePath);
            if isfield(S, 'plugins')
                specs = nansen.unittest.plugin.fixture.TestSpec.empty;
                for i = 1:numel(S.plugins)
                    specs(end+1) = nansen.unittest.plugin.fixture.TestSpec.fromSidecarStruct( ...
                        S.plugins(i), filePath); %#ok<AGROW>
                end
            else
                specs = nansen.unittest.plugin.fixture.TestSpec.fromSidecarStruct(S, filePath);
            end
        end

        function spec = fromSidecarStruct(S, sourcePath)
        %fromSidecarStruct Build a TestSpec from a decoded JSON struct.
            arguments
                S (1,1) struct
                sourcePath (1,1) string = ""
            end

            opts = struct();
            if isfield(S, 'id');          opts.Id          = string(S.id);          end
            if isfield(S, 'displayName'); opts.DisplayName = string(S.displayName); end
            if isfield(S, 'description'); opts.Description = string(S.description); end
            if isfield(S, 'version');     opts.PluginVersion = string(S.version);   end
            if isfield(S, 'source');      opts.Source      = string(S.source);      end
            if isfield(S, 'provider');    opts.Provider    = S.provider;            end
            if isfield(S, 'implementation'); opts.Implementation = S.implementation; end
            if isfield(S, 'capabilities') && ~isempty(S.capabilities)
                opts.Capabilities = string(S.capabilities);
            end
            if isfield(S, 'testTag');     opts.TestTag     = string(S.testTag);     end

            opts.SourcePath = sourcePath;

            spec = nansen.unittest.plugin.fixture.TestSpec(opts);
        end
    end
end
