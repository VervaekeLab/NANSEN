classdef NansenToolboxWrapper < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Abstract)
        ToolboxName
    end
    
    methods
        function obj = GRaFTWrapper(inputArg1)
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 ;
        end
    end
    
    
    
    methods (Static)
        function checkDependencies()
            % Default is to do nothing
        end
    end
    
    
    
end

