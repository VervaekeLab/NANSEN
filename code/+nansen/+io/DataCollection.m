classdef DataCollection
%DATACOLLECTION Interface for storing data in a data collection
%   Within nansen, a data collection would typically be a collection of
%   data variables that are related to an experimental recording. The 
%   aim of the data location is to provide an interface for acessing 
%   the different data from an experimental recording without
%   specifying explicitly where the data variables are located. 
%
%   To achieve this, the user has to define a DataLocation and a
%   VariableMap.
%
%   See also nansen.io.DataLocation nansen.io.VariableMap
    

    properties
        Name
        DataLocation nansen.io.DataLocation % scalar or list?
        VariableMap nansen.io.VariableMap % tabular
        Data
    end
    
    
    methods % Structors
        function obj = DataCollection()
            %DATACOLLECTION Construct an instance of this class
            %   Detailed explanation goes here
            
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
        
    end
    
    methods (Sealed)
        
        function varargout = subsref(obj, S)
            % Todo:
            % Use loadData if the Data is the first entry in subs
            
        end
        
        
        function subsasgn(obj, S, data)
            
            % Use saveData if the Data is the first entry in subs

            
        end
        
        
    end
    
    methods
        
        function data = getVariable(obj, variableName, varargin)
            
        end
        
        function setVariable(obj, variableName, data, varargin)
            
        end
        
    end
    
    
end

