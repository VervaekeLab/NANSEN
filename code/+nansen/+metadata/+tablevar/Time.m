classdef Time < nansen.metadata.abstract.TableVariable
%TIME Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = []
    end
    
    methods
        function obj = Time(S)
            obj@nansen.metadata.abstract.TableVariable(S);
        end
        
        function str = getCellDisplayString(obj)
            str = datestr(obj.Value, 'HH:MM:SS');
        end
    end
    
end