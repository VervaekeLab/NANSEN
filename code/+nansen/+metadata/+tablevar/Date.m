classdef Date < nansen.metadata.abstract.TableVariable & nansen.metadata.abstract.TableColumnFormatter
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
            if ~nargin; S = ''; end
            obj@nansen.metadata.abstract.TableVariable(S);
        end
        
        function str = getCellDisplayString(obj)

            if isa(obj(1).Value, 'datetime')
                dtVector = [obj.Value];
                dtVector.Format = obj.DisplayFormat;
                dtChar = char(dtVector);
                dtChar = [repmat( sprintf('\t\t'), numel(obj), 1) , dtChar];
                str = mat2cell(dtChar, ones(numel(obj),1), size(dtChar,2) );
                
            elseif isa(obj(1).Value, 'char')
                str = {obj.Value};
                
            else
                str = repmat({'N/A'}, 1, numel(obj));
            end
        end
        
    end
    
    methods (Static)
        function value = update(sessionObject)
            value = sessionObject.assignDateInfo();
        end
    end
    
end