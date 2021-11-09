classdef structAdapter < utility.class.nakedhandle & matlab.mixin.SetGet
%utility.class.structAdapter Interface for converting an object to a struct.
%
%   This class can also be used to initialize an object from a struct or 
%   cell array of name value pairs that will be assigned to properties upon
%   instantiation.
%
%   Important for subclassing: 
%       1) Use the Transient attribute of properties of subclasses to
%       define properties that are ignored when adapting to/from struct. The
%       methods of this class only applies to properties that are not
%       Transient.
%       2) All properties need to have a default value.
%   
%
%   Parse inputs in the form of either a) cell array of name value pairs or
%   b) a struct of fields reflecting class properties. This class should
%   also convert an object to a struct, or vice versa. This class ignores
%   all transient properties.
%
%   Dependencies: parsenvpairs

%   Todo:
%       1) implement fromStruct method...
%       2) apply on children objects as well.
%       3) remove point 2 from list above. if there is no default property
%       value, this class should just assume it is empty.

% NB: Need to resolve the discrepency with using transient attribute in
% parser and hidden attribut in toStruct.

    methods (Access = protected)
    
        function parseInputs(obj, varargin)
            
            mc = metaclass(obj);
            
            % Get all property names
            propertyNames = {mc.PropertyList.Name}; 
            isTransient = [mc.PropertyList.Transient];
            propertyNames = propertyNames(~isTransient);
            
            % Get default values.
            defaultValues = {mc.PropertyList(~isTransient).DefaultValue};
            S = cell2struct(defaultValues, propertyNames, 2);
            S = utility.parsenvpairs(S, 1, varargin);
            
            for i = 1:numel(propertyNames)
                obj.(propertyNames{i}) = S.(propertyNames{i});
            end
            
        end
    end
    
    methods
        
        function S = toStruct(obj)
        %toStruct Convert class instance to a struct.
        %
        %   Note: obj can be a single instance or a vector of instances.
        
            mc = metaclass(obj);

            % Get all property names 
            propertyNames = {mc.PropertyList.Name}; 
            isTransient = [ mc.PropertyList.Hidden ];
            propertyNames = propertyNames(~isTransient);
            
            % Get all values for these properties
            values = get(obj, propertyNames);
            
            % Assign names and values to a struct.
            S = cell2struct(values, propertyNames, 2);
            
            % Check if any of the properties are instances of the
            % structAdatpter class.
            
            for iProp = 1:numel(propertyNames)
                thisProp = propertyNames{iProp};
                for jInstance = 1:numel(S)
                    if isa( S(jInstance).(thisProp), 'utility.class.structAdapter' )
                        S(jInstance).(thisProp) = S(jInstance).(thisProp).toStruct();
                    end
                end
            end
            
% %             for i = 1:numel(S)
% %                 if isfield(S(i), 'Children') && ~isempty(S(i).Children) && isa(S(i).Children, 'utility.class.structAdapter')
% %                     S(i).Children = S(i).Children.toStruct();
% %                 end
% %             end
            
        end
        
        
        function fromStruct(obj)
            
            
        end
        
        
% % %         function saveobj()
% % %             
% % %         end
        
    end
    
end