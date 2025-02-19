classdef MetadataExtractor < nansen.common.mixin.StructConvertible
    
    properties
        VariableName (1,1) string
        SubfolderLevel (1,1) double
        StringDetectMode (1,1) string
        StringDetectInput (1,1) string
        StringFormat (1,1) string
        FunctionName (1,1) string
    end
    
end