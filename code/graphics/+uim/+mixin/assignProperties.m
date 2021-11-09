classdef assignProperties < uim.handle & matlab.mixin.SetGet
%assignProperties Class interface for parsing inputs to properties. 
%
%   Parse inputs in the form of either a) cell array of name value pairs or
%   b) a struct of fields reflecting class properties. This class should
%   also convert an object to a struct, or vice versa. This class ignores
%   all transient properties.
%
%   Dependencies: parsenvpairs

%   Todo: implement fromStruct method...

    methods (Access = protected)
    
        function parseInputs(obj, varargin)
            
            % NOTE! It is important that the varargin inputs are set to
            % property values after default because some properties depend
            % on each other. 
            
            % NOTE2. No idea why I use utility.parsenvpairs here. Is it
            % just something I did for speed, but which creates problem
            % with dependent properties??
            
            nvPairs = obj.addComponentDefaultValues(varargin);

            mc = metaclass(obj);
           
            % Find all public & non transient properties
            isTransient = [ mc.PropertyList.Transient ];
            isPublic = strcmp( { mc.PropertyList.SetAccess }, 'public');
            
            keep = ~isTransient & isPublic;
                        
            % Get names and default values for the properties to keep.
            propArray = mc.PropertyList(keep);
            propertyNames = {propArray.Name};
            defaultValues = cell(1, length(propArray));
            
            hasDefaults = [propArray.HasDefault];
            defaultValues(hasDefaults) = {propArray(hasDefaults).DefaultValue};

            %defaultValues = {mc.PropertyList(~isTransient & isPublic).DefaultValue};
            
            S = cell2struct(defaultValues, propertyNames, 2);
            S = utility.parsenvpairs(S, 1, nvPairs);
            
            S = utility.nvpairs2struct(nvPairs);
            
            % Only set varargins...
            
            for i = 1:numel(propertyNames)
                if isfield(S, propertyNames{i})
                    obj.(propertyNames{i}) = S.(propertyNames{i});
                end
            end
            
        end
        
        
        function varargout = addComponentDefaultValues(obj, cellOfArgin)
            % Question: Are subclass defaults overriding superclass
            % defaults now?
            
            S = obj.getDefaultPropertyValues;
            
            propNames = cellOfArgin(1:2:end);
            propValues = cellOfArgin(2:2:end);
            
            for i = 1:numel(propNames)
                S.(propNames{i}) = propValues{i};
            end
            
            C = cat(1, fieldnames(S)', struct2cell(S)');
            C = C(:)';
            
            varargout = {C};
            
            %parseInputs@uim.mixin.assignProperties(obj, C{:})
        
        end
        
    end
        
    methods (Static, Access = protected)
            
        function S = getDefaultPropertyValues()
            % Subclass may override
            S = struct;
        end
        
    end
    
    methods
        
        function S = toStruct(obj)

            mc = metaclass(obj);

            % Get all property names
            propertyNames = {mc.PropertyList.Name}; 
            isTransient = [ mc.PropertyList.Hidden ];
            propertyNames = propertyNames(~isTransient);
            
            values = get(obj, propertyNames);
            S = cell2struct(values, propertyNames, 2);
            
        end
        
        
        function fromStruct(obj)
            
            
        end
        
        
% % %         function saveobj()
% % %             
% % %         end
        
    end
    
end