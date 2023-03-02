classdef StatusText < handle & dynamicprops


% Dynamic property implementation based on:
% https://se.mathworks.com/matlabcentral/answers/48831-set-methods-for-dynamic-properties-with-unknown-names#answer_179574

    properties (Hidden)
        Delimiter = ' | ';
        UpdateFcn
    end

    properties (SetAccess = immutable, Hidden)
        PropertyNames % List of properties in the order they should appear
    end

    properties (Access = private)
        Data % Struct for holding all the property values
    end

    methods 
        function obj = StatusText(propertyNames)
            obj.PropertyNames = propertyNames;

            for i = 1:numel(obj.PropertyNames)
                thisPropertyName = obj.PropertyNames{i};
                obj.addDynamicProperty(thisPropertyName)
            end
        end
    end

    methods 
        function newText = getText(obj)
            
            textSnippets = {};
            
            for i = 1:numel(obj.PropertyNames)
                thisValue = obj.Data.(obj.PropertyNames{i});
                
                if ischar(thisValue) && isempty(thisValue)
                    continue
                elseif isstring(thisValue) && thisValue==""
                    continue
                else
                    textSnippets{end+1} = char(thisValue); %#ok<AGROW> 
                end
            end
            
            newText = strjoin(textSnippets, obj.Delimiter);
        end
    end

    methods (Access = private)
        function addDynamicProperty(obj, name)
            prop = obj.addprop(name);
            prop.Dependent = true;
            prop.GetMethod = @(obj) getDynamicPropertyValue(obj, name);
            prop.SetMethod = @(obj, val) setDynamicPropertyValue(obj, name, val);
            obj.Data.(name) = '';
        end

        function val = getDynamicPropertyValue(obj, name)
            val = obj.Data.(name);
        end

        function setDynamicPropertyValue(obj, name, val)
            assert(ischar(val) || isstring(val), 'Value must be text')
            obj.Data.(name) = val;
            updatedText = obj.getText();
            obj.UpdateFcn(updatedText)
        end
    end
end
