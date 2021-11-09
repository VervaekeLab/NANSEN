function propertyNames = findproperties(obj, attributeName, attributeValue)
%utility.class.findproperties Find properties with specific attribute
%
%   propertyNames = utility.class.findproperties(obj, attrName)
%   returns the name of all properties in the class object (obj) which has
%   the attribute specified by the attribute name (attrName) flagged to true
%
%   propertyNames = utility.class.findproperties(obj, attrName, attrValue)
%   returns the name of all properties that has the attribute name set to
%   the specified attribute value (attrVal)
%
%   Example 1:
%       propNames = utility.class.findproperties(obj, 'Hidden')
%
%   Example 2:
%       propNames = utility.class.findproperties(obj, 'SetAccess', 'private')
%



%   set to the specified attribute value (attrValue)

    if nargin < 2; attributeName = ''; end
    if nargin < 3; attributeValue = true; end


    % Get the metaclass object for the input obj/classname
    if ischar(obj)
      mc = meta.class.fromName(obj);
    elseif isobject(obj)
      mc = metaclass(obj);
    end
    
    
    % Get all property names
    propertyNames = {mc.PropertyList.Name}; 
    
    
    if isempty(attributeName)
        return % Return all property names
    elseif isempty (findprop(mc.PropertyList(1), attributeName))
        % Throw error if attribute name is invalid.
        error('%s is not a valid attribute name', attributeName)
    end
    
    
    % Match properties with the specified. attribute.
    if islogical(mc.PropertyList(1).(attributeName) )
        isMatched = [ mc.PropertyList.(attributeName) ] == attributeValue;
    else
        allAttributeValues = { mc.PropertyList.(attributeName) };
        isMatched = contains(allAttributeValues, attributeValue);
    end
    
    propertyNames = propertyNames(isMatched);
    
    
end