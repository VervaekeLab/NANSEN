classdef DummyArray
    %DUMMYARRAY Summary of this class goes here
    %   Holds size and data type for array, useful for initializing files
    %   with arrays that are too large to fit in memory.
    
    properties (SetAccess = protected) % Size and type of original data
        DataSize                        % Length of each dimension of the original data array
        DataType                        % Data type for the original data array
    end
    
    properties (SetAccess = private) 
        IsInitialized = false
    end
    
    methods
        function obj = DummyArray(inputArg1,inputArg2)
            %DUMMYARRAY Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1 + inputArg2;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

