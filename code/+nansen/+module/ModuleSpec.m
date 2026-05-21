classdef ModuleSpec < nansen.common.abstract.Specification
%ModuleSpec Metadata parsed from a NANSEN module manifest.
%
%   A module is a package/provider boundary, not a plugin. ModuleSpec parses
%   module.nansen.json files and keeps module-level metadata in the
%   nansen.module namespace.

    properties (Constant)
        TYPE = "NANSEN Module Specification"
        VERSION = "1.0.0"
    end

    properties (Access = protected)
        RequiredProperties = ["Name", "Description"]
    end

    properties
        Name (1,1) string = missing
        Description (1,1) string = ""
        ModuleVersion (1,1) string = ""
        MinNansenVersion (1,1) string = ""
        MaxNansenVersion (1,1) string = ""
        Dependencies (1,:) struct = struct.empty(1, 0)
        Provides (1,:) struct = struct.empty(1, 0)
    end

    methods
        function obj = ModuleSpec(options)
        %ModuleSpec Construct a module specification from a property struct.
            arguments
                options (1,1) struct = struct()
            end
            obj@nansen.common.abstract.Specification(options)
        end

    end

    methods (Static)
        function spec = fromJsonFile(filePath)
        %fromJsonFile Read a module specification from module.nansen.json.
            arguments
                filePath (1,1) string {mustBeFile}
            end

            raw = jsondecode(fileread(filePath));
            if isfield(raw, 'Properties')
                raw = raw.Properties;
            end

            spec = nansen.module.ModuleSpec.fromStruct(raw);
        end

        function spec = fromStruct(S)
        %fromStruct Build a ModuleSpec from decoded manifest properties.
            arguments
                S (1,1) struct
            end

            opts = struct();
            if isfield(S, 'Name');             opts.Name = string(S.Name);                         end
            if isfield(S, 'Description');      opts.Description = string(S.Description);           end
            if isfield(S, 'ModuleVersion');    opts.ModuleVersion = string(S.ModuleVersion);       end
            if isfield(S, 'MinNansenVersion'); opts.MinNansenVersion = string(S.MinNansenVersion); end
            if isfield(S, 'MaxNansenVersion'); opts.MaxNansenVersion = string(S.MaxNansenVersion); end
            if isfield(S, 'Dependencies');     opts.Dependencies = S.Dependencies;                 end
            if isfield(S, 'Provides');         opts.Provides = S.Provides;                         end

            spec = nansen.module.ModuleSpec(opts);
        end
    end
end
