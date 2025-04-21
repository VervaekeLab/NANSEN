classdef MetadataEntity < nansen.util.StructAdapter & dynamicprops
%MetadataEntity Basis class for a metadata object definition.
%
% Properties are metadata info.
%
% Using a class makes it possible to use validation.
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

%   Todo
%       [ ] Add methods for interacting with a metatable?

    properties (Abstract, Constant, Hidden)
        ANCESTOR
        IDNAME
    end
    
    properties (Constant, Hidden)
    end
    
    properties %(Abstract)
        Notebook = struct.empty        % struct
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
    
    methods (Access = private)
                      
        function obj = constructFromTable(obj, metaTable)
        %constructFromTable Construct object(s) from meta table
        %
        %   metaObj.constructFromTable(metaTable) constructs a vector of
        %   objects from a table
        
        %   Note: Need to return obj, because this function might change
        %   the size of obj.
        
            % Count table rows
            numObjects = size(metaTable,1);
            % Use notebook field to initialize a vector of objects
            obj(numObjects).Notebook = struct.empty;
            % Assign object properties from meta table
            obj.fromTable(metaTable)
        end
    end
    
    methods % Methods for retyping
        
        function fromStruct(obj, S)
            
            numObjects = numel(S);
            propertyNames = fieldnames(S);
            
            for jProp = 1:numel(propertyNames)
                if isprop(obj, propertyNames{jProp})
% %                     for i = 1:numObjects
% %                         obj(i).(propertyNames{jProp}) = S(i).(propertyNames{jProp});
% %                     end
                    try
                        [obj.(propertyNames{jProp})] = S.(propertyNames{jProp});
                    catch ME
                        switch ME.identifier
                            case "MATLAB:class:SetProhibited"
                                % Silently ignore
                                % Todo: Need a strategy/guideline for this case
                            otherwise
                                warning('Could not set property %s', propertyNames{jProp})
                        end
                    end
                else
                    P = obj.addprop(propertyNames{jProp});
                    for i = 1:numObjects
                        obj(i).(propertyNames{jProp}) = S(i).(propertyNames{jProp});
                    end
                    % Dynamic props can only be set from within the class
                    [P.SetAccess] = deal('protected');
                end
            end
        end
        
        function S = toStruct(obj)
        %TOSTRUCT Convert object to a struct. Skip Notebook property.
            
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
            obj(numObjects).Notebook = struct.empty;
            obj.fromStruct(S);
        end
    end
    
    methods
        function addNote(obj, note)
            
            if isa(note, 'nansen.notes.Note')
                noteStruct = struct(note);
            elseif isa(note, 'struct')
                noteStruct = note;
            else
                error('Invalid input')
            end
            
            if isempty(obj.Notebook)
                obj.Notebook = noteStruct;
            else
                obj.Notebook(end+1) = noteStruct;
            end
            
            evtData = obj.getPropertyChangedEventData('Notebook');
            obj.notify('PropertyChanged', evtData)
        end
    end
    
    methods (Access = protected)
        
        function evtData = getPropertyChangedEventData(obj, propertyName)
            
            newValue = obj.(propertyName);
            if isa(newValue, 'struct'); newValue = {newValue}; end
            
            evtData = uiw.event.EventData('Property', propertyName, ...
                'NewValue', newValue);
        end
    end
end
