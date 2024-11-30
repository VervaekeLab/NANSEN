classdef TableVariable
%nansen.metadata.abstract.TableVariable Implement a custom variable type to
%display in a table cell.
%
%   Subclasses must implement a Value and two methods, one for creating a
%   string to be displayed within a cell and one for creating a string to
%   be displayed as a tooltip (getCellDisplayString, getCellTooltipString
%   respectively).
%
%   Note: Subclasses should work on vectors of objects, and return cell
%   arrays of formatted strings with one cell for each object.

%   Todo:
%       [ ] Static update function. Think more about this. All table
%           variables should have an update function, but should it be static,
%           and how to implement that in a way where it is optional for the
%           subclass to implement it or not?

    properties (Constant, Abstract)
        IS_EDITABLE
        DEFAULT_VALUE
    end
    
    properties
        Value
    end
    
%     events % Need to inherit from handle if this is implemented:
%         ValueChanged
%     end
    
    methods % Constructor
        function obj = TableVariable(S)
            
            if nargin < 1 || isempty(S)
                obj.Value = struct.empty;
                return
            end

            if iscell(S)
                numObjects = numel(S);
                [obj(1:numObjects).Value] = deal( S{:} );
                
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

    methods % Subclasses can override (Methods for cell display & interaction)
        
        function str = getCellDisplayString(obj)
        %getCellDisplayString Get formatted string to display in table cell
            if numel(obj) > 1
                str = repmat({''}, 1, numel(obj));
            elseif numel(obj) == 1
                str = '';
            end
        end

        function str = getCellTooltipString(obj)
        %getCellTooltipString Get string to display in tooltip on mouseover
            if numel(obj) > 1
                str = repmat({''}, 1, numel(obj));
            elseif numel(obj) == 1
                str = '';
            end
        end
        
        function [] = onCellDoubleClick(obj, metaObj, varargin)
            % Do nothing. Subclass may override
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
    
    methods (Static)
        % Subclasses can implement update....How to formalize this???
        % Subclasses should be allowed not to have the update method...
    end
    
    methods (Static)
        % Function in separate file
        attributeTable = buildTableVariableTable(fileList)

        S = getDefaultTableVariableAttribute()

        defaultTableVariableList = getDefaultTableVariables(metadataType)

    end
end
