classdef TableVariable
%nansen.metadata.abstract.TableVariable Implement a custom variable type to
%display in a table cell. 
%
%   
%   Subclasses must implement a Value and two methods, one for creating a
%   string to be displayed within a cell and one for creating a string to
%   be displayed as a tooltip (getCellDisplayString, getCellTooltipString
%   respectively).
%
%   


    properties (Constant, Abstract)
        IS_EDITABLE
        DEFAULT_VALUE
    end

    
    properties
        Value
    end
    
    
% %     methods (Abstract)
% %         str = getCellDisplayString(obj)
% %         str = getCellTooltipString(obj)
% %     end
    
    
    methods
        function obj = TableVariable(S)
            
            if nargin < 1
                return
            end

            if iscell(S) 
                S = S{1};
                obj.Value = S;
                
            elseif isa(S, 'nansen.metadata.abstract.BaseSchema')
                varName = obj.getVariableName;
                
                % Todo: Should retrieve value from dynamic prop if prop is
                % not hardcoded...
                if isprop(S, varName)
                    obj.Value = S.(varName);
                else
                    obj.Value = obj.DEFAULT_VALUE;
                end
                
            else
                obj.Value = S;
            end
            
        end
    end
    
    
    
    methods % Subclasses can override
        
        function str = getCellDisplayString(obj)
        %getCellDisplayString Format the progress struct into a progressbar
            str = '';
        end
        
        function str = getCellTooltipString(obj)
            str = '';
        end
        
    end
    
    methods
        
        function varName = getVariableName(obj)
        %getVariableName Get variable name from the class definition name
            
            className = class(obj);
            classNameSplit = strsplit(className, '.');
            varName = classNameSplit{end};
        end
        
    end
    
end