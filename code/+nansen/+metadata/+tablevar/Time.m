classdef Time < nansen.metadata.abstract.TableVariable
%TIME Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = []
    end
    
    properties
        TimeFormat = 'HH:mm:ss'
    end
    
    methods
        
        function obj = Time(S)
            obj@nansen.metadata.abstract.TableVariable(S);
        end
        
        function str = getCellDisplayString(obj)
        %getCellDisplayString Return text to display in cell of table
            
            if isa(obj.Value, 'datetime')
                obj.Value.Format = obj.TimeFormat;
                str = sprintf(['\t\t', char(obj.Value)]);
            elseif isa(obj.Value, 'char')
                str = obj.Value;
            else
                str = 'N/A';
            end
            
        end
        
%         function value = getValue(obj)
%             
%         end
    end
    
end