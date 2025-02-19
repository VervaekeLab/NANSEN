classdef (Abstract) Item < nansen.common.mixin.StructConvertible
% Item - Abstract class for an item, a unique and named entity

    properties
        Name (1,1) string
        Description (1,1) string = ""
    end

    properties (SetAccess = private, Hidden)
        UUID
    end
    
    methods % Constructor
        function obj = Item(propertyName, propertyValue, itemProps)
            arguments (Repeating)
                propertyName
                propertyValue
            end
            arguments
                itemProps.?nansen.metadata.abstract.Item
                itemProps.UUID (1,1) string {mustBeUUID} = missing
            end
            
            itemProps = obj.setPrivateItemProps(itemProps);
            obj.set(itemProps)
            
            subclassProps = cell2struct(propertyValue, propertyName, 2);
            subclassProps = obj.setPrivateProps(subclassProps);
            obj.set(subclassProps)
        end
    end

    methods (Access = protected)
        function itemProps = setPrivateProps(obj, itemProps) %#ok<INUSD>
            % Subclasses can override
        end
    end

    methods (Access = private)
        function itemProps = setPrivateItemProps(obj, itemProps)
            if ismissing(itemProps.UUID)
                obj.UUID = matlab.lang.internal.uuid();
            else
                obj.UUID = itemProps.UUID;
            end
            itemProps = rmfield(itemProps, 'UUID');
        end
    end

    methods (Static)
        function obj = fromStruct(S, subclassName)
            classConstructorFcn = str2func(subclassName);
            nvPairs = namedargs2cell(S);
            obj = feval(classConstructorFcn, nvPairs{:});
        end

        function obj = fromJson(fileName, subclassName)
            S = readstruct(fileName);
            fromStructFcn = sprintf('%s.fromStruct', subclassName);
            obj = feval(fromStructFcn, S);
        end
    end
end

function mustBeUUID(value)
    arguments
        value (1,1) string = missing
    end

    if ismissing(value)
        return
    end

    %segmentLength = [8, 4, 4, 4, 12];
    %pattern = "^" + join(compose("[0-9a-fA-F]{%d}", segmentLength), "-") + "$";
        
    % Define a regular expression for a UUID.
    % This pattern matches the canonical 8-4-4-4-12 hexadecimal format.
    pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    
    % Use regexp to see if the value is a match.
    isValid = ~isempty(regexp(value, pattern, 'once'));
    
    % Assert that the uuid matches the pattern.
    assert(isValid, 'mustBeUUID:InvalidUUID', 'Value must be a valid UUID.');
end
