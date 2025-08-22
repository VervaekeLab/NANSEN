classdef FileAdapterMeta < nansen.internal.plugin.AbstractPluginSpec

    properties (Constant)
        TYPE = "FileAdapter"
        VERSION = "1.0.0"
    end

    properties (Access = protected)
        RequiredProperties = ["Name", "SupportedFileTypes", "DataType"];
    end

    properties
        Name (1,1) string = missing
        Description (1,1) string = ""
        SupportedFileTypes (1,:) string = missing
        FileExpression (1,1) string = ""
        DataType (1,1) string = missing
        IsGeneral (1,1) logical = false          % Whether file adaper is general and can open all files of a file format.
        ReadFunction (1,1) string = ""
        WriteFunction (1,1) string = ""
        ViewFunction (1,1) string = ""
    end

    methods
        function toClassStruct(obj)
        end

        function toFunctionStruct(obj)
        end

        function jsonStr = toJson(obj)
            S = obj.toStruct();
            S.Properties.SupportedFileTypes = ...
                cellstr(S.Properties.SupportedFileTypes); % To encode as array in json if value is scalar.
            jsonStr = jsonencode(S, 'PrettyPrint', true);
            jsonStr = obj.fixCustomJsonPropNames(jsonStr);
        end
    end
end
