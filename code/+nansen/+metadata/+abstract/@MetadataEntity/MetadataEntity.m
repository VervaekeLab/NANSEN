% MetadataEntity - Base class for a metadata entity definition.
%
% Properties are metadata info.
%
% Convert to/from struct
% Convert to/from table
%
% A MetaTable is a table of metadata objects which must derive from this
% MetadataEntity class.
%
% Todo: Clarify this..
% When a metadata object is picked from the table it is transformed to an
% object. The object provides methods for updating/plotting
%
%   See also MetaTable

classdef MetadataEntity < ...
        dynamicprops & ...
        nansen.util.StructAdapter & ...
        nansen.metadata.mixin.HasNotes

%   Todo
%       [ ] Add methods for interacting with a metatable?

    properties (Abstract, Constant, Hidden)
        ANCESTOR
        IDNAME
    end

    properties (Transient, SetAccess = immutable, GetAccess = protected)
        IsConstructed = false
    end
    
    events
        PropertyChanged
    end
    
    methods % Constructor
        function obj = MetadataEntity(varargin)
            if ~isempty(varargin) && isa(varargin{1}, 'table')
                obj = obj.constructFromTable(varargin{1});
                [obj.IsConstructed] = deal(true);
            end
        end
    end

    methods
        function addDynamicTableVariables(obj)
            error('Not implemented yet')
        end
    end

    methods (Access = private)
        function value = getType(obj)
            fullClassname = class(obj);
            splitClassName = strsplit(fullClassname, '.');
            value = splitClassName{end};
        end
    end
    
    methods (Access = private)
        function obj = constructFromTable(obj, metaTable)
        %constructFromTable Construct object(s) from meta table
        %
        %   metaObj.constructFromTable(metaTable) constructs a vector of
        %   objects from a table
        
        %   Note: Need to return obj, because this function might change
        %   the size of obj.
        
            % Initialize array of objects
            numObjects = size(metaTable, 1);
            obj(numObjects) = feval(class(obj));

            % Assign object properties from meta table
            obj.fromTable(metaTable)
        end
    
        function createDynamicProperty(obj, propName, S)
        % createDynamicProperty - Helper method to create dynamic properties

            arguments
                obj nansen.metadata.abstract.MetadataEntity
                propName (1,1) string
                S (1,:) struct
            end

            P = obj.addprop(propName);
            for i = 1:numel(obj)
                obj(i).(propName) = S(i).(propName);
            end
            
            % Dynamic props must only be set from within the class
            [P.SetAccess] = deal('protected');
        end
    
    end
    
    methods % Methods for retyping
        
        function fromStruct(obj, S)
            
            assert(numel(obj) == numel(S), ...
                'NANSEN:MetadataEntity:WrongStructLength', ...
                'Input structure must be the same length as the object')
            
            propertyNames = fieldnames(S);
            
            for jProp = 1:numel(propertyNames)
                thisPropertyName = propertyNames{jProp};

                if isprop(obj, propertyNames{jProp})
% %                     for i = 1:numObjects
% %                         obj(i).(propertyNames{jProp}) = S(i).(propertyNames{jProp});
% %                     end
                    try
                        [obj.(thisPropertyName)] = S.(thisPropertyName);
                    catch ME
                        switch ME.identifier
                            case "MATLAB:class:SetProhibited"
                                % Silently ignore
                                % Todo: Need a strategy for this case
                            otherwise
                                warning('Could not set property %s', thisPropertyName)
                        end
                    end
                else
                    obj.createDynamicProperty(thisPropertyName, S)
                end
            end
        end
        
        function S = toStruct(obj)
        %TOSTRUCT Convert object to a struct.
            S = toStruct@nansen.util.StructAdapter(obj);
        end

        function T = makeTable(obj)
            
            for i = 1:numel(obj)
                if i == 1
                    S = obj(i).toStruct();
                else
                    S(i) = obj(i).toStruct();
                end
            end
            
            T = struct2table(S, 'AsArray', true);
        end
        
        function fromTable(obj, dataTable)
           
            S = table2struct(dataTable);
            numObjects = numel(S);
            obj(numObjects) = feval(class(obj));
            
            obj.fromStruct(S);
        end
    end
    
    methods (Access = protected)
        function onNotebookPropertySet(obj)
            evtData = obj.getPropertyChangedEventData('Notebook');
            obj.notify('PropertyChanged', evtData)
        end
        
        function evtData = getPropertyChangedEventData(obj, propertyName)
            newValue = obj.(propertyName);
            % Todo: This should either be improved, or documented, i.e why
            % is a struct wrapped in a cell array?
            if isa(newValue, 'struct'); newValue = {newValue}; end
            
            evtData = uiw.event.EventData('Property', propertyName, ...
                'NewValue', newValue);
        end
    end
end
