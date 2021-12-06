classdef Date < nansen.metadata.abstract.TableVariable
%DATE Definition for table variable
%   Detailed explanation goes here
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = []
    end
    
    methods
        function obj = Date(S)
            obj@nansen.metadata.abstract.TableVariable(S);
        end
        
        function str = getCellDisplayString(obj)
            str = datestr(obj.Value, 'yyyy.mm.dd');
        end
    end
    
end