classdef Time < nansen.metadata.abstract.TableVariable & nansen.metadata.abstract.TableColumnFormatter
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
        
        function obj = Time(varargin)
            obj@nansen.metadata.abstract.TableVariable(varargin{:});
        end
        
        function str = getCellDisplayString(obj)
        %getCellDisplayString Return text to display in cell of table
            
            if isa(obj(1).Value, 'datetime')
                dtVector = [obj.Value];
                dtVector.Format = obj.TimeFormat;
                dtChar = char(dtVector);
                dtChar = [repmat( sprintf('\t\t'), numel(obj), 1) , dtChar];
                str = mat2cell(dtChar, ones(numel(obj),1), size(dtChar,2) );
                
            elseif isa(obj(1).Value, 'char')
                str = {obj.Value};
                
            else
                str = repmat({'N/A'}, 1, numel(obj));
            end
        end
        
%         function value = getValue(obj)
%
%         end
    end
end

% % %     % Slower to get formatted character vectors from loop.
% % %     tic
% % %     str = repmat({''}, numel(obj), 1 );
% % %     for i = 1:numel(obj)
% % %         if isa(obj(i).Value, 'datetime')
% % %             obj(i).Value.Format = obj.TimeFormat;
% % %             str{i} = sprintf(['\t\t', char(obj(i).Value)]);
% % %         end
% % %     end
% % %     toc
            
