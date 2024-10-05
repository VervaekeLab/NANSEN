classdef MetadataModel < handle

    properties (Dependent)
        Name
    end

    methods (Abstract)
    
        schemaNames = listSchemaNames(obj, tableType)

    end

    methods % Set/Get methods

        function name = get.Name(obj)
            
            className = builtin('class', obj);
            classNameSplit = strsplit(className, '.');
            name = classNameSplit{end};

        end
    end
end
