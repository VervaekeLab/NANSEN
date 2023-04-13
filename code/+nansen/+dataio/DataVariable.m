classdef DataVariable < File
    
    properties 
        DataSet
        InitPath % Property of File?
    end

    properties 
        Subfolder
        FileAdapter
    end
    

    methods

        function obj = DataVariableFileArchivist()

            % Make sure either dataset or initpath is set.
        end
    end

    methods
        function uiput(obj)

        end

        function uiget(obj)

        end
    end

    methods (Access = protected)
        
        function variableName = uiGetVariableName(obj)
            
            % Get existing variables from data set

            variableName = uics.inputOrSelect(getFruits(3), 'ItemName', 'data variable name');

        end

        function createDataVariable(obj)
            % Create variable and add to dataset
        end
    end
    
end