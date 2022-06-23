classdef Directory
    %DIRECTORY Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties
        Type
    end
    
    properties (Access = protected)
    	FolderPath
    end
    
    
    methods
        function obj = Directory(inputArg1,inputArg2)
            %DIRECTORY Construct an instance of this class
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

