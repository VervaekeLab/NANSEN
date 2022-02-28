classdef Date < nansen.metadata.abstract.TableVariable
%DATE Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = []
    end
    
    properties
        DisplayFormat = 'MMM-dd-yyyy';
    end
    
    methods
        function obj = Date(S)
            obj@nansen.metadata.abstract.TableVariable(S);
        end
        
        function str = getCellDisplayString(obj)
            
            if isa(obj.Value, 'datetime')
                obj.Value.Format = obj.DisplayFormat;
                str = sprintf(['\t\t', char(obj.Value)]);
            elseif isa(obj.Value, 'char')
                str = obj.Value;
            else
                str = 'N/A';
            end
        end
        
    end
    
    methods (Static)
        function value = update(sessionObject)
            value = sessionObject.assignDateInfo();
        end
    end
    
end