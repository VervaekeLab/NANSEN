classdef FileAdapterMeta < nansen.internal.plugin.AbstractPluginSpec

    properties (Constant)
    end

    properties
        Name (1,1) string = ""
        Description (1,1) string = ""
        SupportedFileTypes (1,:) string = ""
        FileExpression (1,1) string = ""
        DataType (1,1) string = ""
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
    end
end
