classdef AbstractPluginSpec < nansen.common.abstract.Specification

    properties (Transient)
        ImplementationType (1,1) nansen.internal.plugin.enum.ImplementationType = "Function"
    end

    methods
        function S = toStruct(obj)
            C = obj.toCell();
            props = struct(C{:});
            props = rmfield(props, 'ImplementationType'); % Todo should be automatically removed because of being transient
            props = rmfield(props, {'TYPE', 'VERSION'});

            S = struct();
            S.x_type = obj.TYPE;
            S.x_version = obj.VERSION;
            S.Properties = props;
        end
    end
end
