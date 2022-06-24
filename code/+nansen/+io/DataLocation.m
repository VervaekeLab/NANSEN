classdef DataLocation
    %DATALOCATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods
        function obj = DataLocation(inputArg1,inputArg2)
            %DATALOCATION Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1 + inputArg2;
        end
        
        function pathString = getDataFolder(obj, inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            pathString = obj.Property1 + inputArg;
        end
    end
end

