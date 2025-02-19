classdef (Abstract) StructConvertible < handle & matlab.mixin.SetGet
%STRUCTCONVERTIBLE Convert objects and object arrays to/from structs.
%
% This class provides functionality for converting MATLAB objects into
% structs, and for reconstructing objects from those structs. It is
% particularly useful for serialization, as the resulting struct can
% then be encoded into formats like JSON or stored in MAT-files.
%
% When converting objects to a struct using the `toStruct` method, you
% can specify whether to include hidden, or transient properties. Dependent 
% properties are always skipped. You may also optionally include a context 
% header that stores metadata about the object array, such as its class name 
% and number of elements.
%
% Converting from a struct back to an object (or array of objects) is
% handled by `fromStruct`. If the struct includes the context header,
% the class name can be inferred directly; otherwise, you must provide
% the class name. In cases where the struct does not represent an
% object (e.g., it lacks the necessary context and class information),
% the `fromStruct` method can return the struct as-is if configured to
% do so.
%
% Typical usage:
%   obj = SomeClass(...);
%   S = obj.toStruct('WithContext', true);
%   % Encode S to JSON, save to file, etc.
%   % ...
%   % Later, reconstruct the object:
%   newObj = nansen.common.mixin.StructConvertible.fromStruct(S);
%
% This class relies on MATLAB's metaclass reflection to discover object
% properties, making it easy to apply uniformly to many classes. It is
% intended to serve as a mixin or a base class in a class hierarchy,
% enabling a consistent approach to object serialization.
%
% Properties:
%   ConvertHidden     - (logical) Include hidden properties when converting to struct.
%   ConvertTransient  - (logical) Include transient properties.
%   ConvertProtected  - (logical) Include protected properties (not yet fully supported).
%   WithHeader        - (logical) If set, add context metadata to the returned struct.
%
% Methods:
%   toStruct          - Convert one or more objects into a struct (array).
%   toTable           - Convert an object array into a table (if possible).
%   fromStruct        - Reconstruct objects from a struct or struct array.
%
% Note:
%   While nansen.common.mixin.StructConvertible greatly simplifies 
%   serialization, users should ensure that all properties are compatible with 
%   the chosen serialization format. For example, `toTable` may not work if
%   certain properties cannot be represented as table variables.
%
% See also: jsonencode, jsondecode, metaclass, struct2table, table2struct

% Written by Eivind Hennestad using chatGPT-o1

% Todo: toStruct should be recursive...

    properties (SetAccess = immutable, GetAccess = private, Transient) % Preferences
        ConvertHidden (1,1) logical = false
        ConvertTransient (1,1) logical = false
        ConvertProtected (1,1) logical = false 
        ConvertPrivate (1,1) logical = false
        ExcludeSuperclass (1,:) string = string.empty % List of names of superclasses to exclude (Todo)
    end
    properties (Access = protected, Transient) % Preferences
        Include (1,:) string = string.empty
    end

    methods (Access = ?nansen.common.mixin.StructConvertible)
        function value = getPrivate(obj, privatePropertyName) %#ok<INUSD,STOUT>
            error('StructConvertible:Convert', ...
                ['Subclass must implement `getPrivate` method in order ', ...
                 'to convert private properties'] )
        end
    end

    methods
        function S = toStruct(obj, options)
        %TOSTRUCT Convert object(s) to a struct or struct array.
        %
        % Syntax:
        %  S = obj.toStruct() returns a struct array representing the
        %  object array 'obj'. Each field of the struct corresponds to a
        %  property of the object. By default, dependent properties are
        %  skipped, and only public, non-hidden, non-protected, and
        %  non-transient properties are included.
        %
        %  S = obj.toStruct(Name, Value) allows specifying additional
        %  options:
        %    'ConvertHidden'     - (logical) Include hidden properties.
        %    'ConvertTransient'  - (logical) Include transient properties.
        %    'ConvertProtected'  - (logical) Include protected properties.
        %    'ConvertPrivate'    - (logical) Include protected properties.
        %    'WithContext'       - (logical) If true, a header struct is
        %                          included that records context about
        %                          the object array, such as its class
        %                          name and number of elements.
        %
        % Returns:
        %   S - A struct or struct array representing the object(s).
        %
        % Example:
        %   obj = SomeClass(...);
        %   S = obj.toStruct('WithContext', true);
        %   jsonStr = jsonencode(S);

            arguments
                obj (1,:) nansen.common.mixin.StructConvertible
                options.ConvertHidden (1,1) logical = obj.ConvertHidden
                options.ConvertTransient (1,1) logical = obj.ConvertTransient
                options.ConvertProtected (1,1) logical = obj.ConvertProtected
                options.ConvertPrivate (1,1) logical = obj.ConvertPrivate
                options.WithContext (1,1) logical = false
            end
           
            mc = metaclass(obj);
            propList = mc.PropertyList;

            % Filter property list
            skip = [propList.Dependent]; % Always skip dependent
            if ~options.ConvertTransient
                skip = skip | [propList.Transient];
            end
            if ~options.ConvertHidden
                skip = skip | [propList.Hidden];
            end
            if ~options.ConvertProtected
                skip = skip | strcmp({propList.GetAccess}, 'protected') ...
                    | strcmp({propList.SetAccess}, 'protected');
            end
            if ~options.ConvertPrivate
                skip = skip | strcmp({propList.GetAccess}, 'private') ...
                    | strcmp({propList.SetAccess}, 'private');
            end

            skip( ismember({propList.Name}, obj(1).Include) ) = false;

            propList(skip) = [];

            S = repmat(struct(), 1, numel(obj));
            
            for iObj = 1:numel(obj)
                for jProp = 1:numel(propList)
                    thisProp = propList(jProp);
                    thisPropName = thisProp.Name;
                    if any(strcmp(thisProp.SetAccess, {'protected', 'private'}))
                        propValue = obj(iObj).getPrivate(thisPropName);
                    else
                        propValue = obj(iObj).(thisPropName);
                    end
                    S(iObj).(thisPropName) = propValue;
                end
            end

            if options.WithContext
                contextStruct = obj.createContextStruct();
                contextStruct.NumObjects = numel(obj);
                contextStruct.ObjectProperties = S;
                S = contextStruct;
            end
        end

        function T = toTable(obj)
        %TOTABLE Convert object array to a table.
        %
        % T = obj.toTable() converts the object array into a table by
        % first obtaining a struct array using toStruct, then using
        % struct2table. This is convenient if the object's properties
        % are compatible with being represented as table variables.
        %
        % If certain properties cannot be converted into a table
        % (e.g., because they are complex nested structures or cell
        % arrays of varying dimensions), this method may fail or
        % produce unexpected results.
        %
        % Returns:
        %   T - A table representing the object array.
        %
        % Example:
        %   objArray = [SomeClass(...), SomeClass(...)];
        %   T = objArray.toTable();

            S = obj.toStruct();
            T = struct2table(S, "AsArray", true);
        end
    end

    methods (Access = private)
        function S = createContextStruct(obj)
        %CREATECONTEXTSTRUCT Create a struct for storing context metadata.
            S.Context = mfilename('class');
            S.Description = 'Struct representation of object / object array';
            S.ObjectClassName = class(obj);
            S.NumObjects = nan;
            S.ObjectProperties = struct.empty;
        end
    end
    
    methods (Sealed, Hidden)
        function set(obj, varargin)
            set@matlab.mixin.SetGet(obj, varargin{:});
        end

        function varargout = get(obj, varargin)
            varargout = get@matlab.mixin.SetGet(obj, varargin{:});
        end
    end

    methods (Static)
        function obj = fromStruct(S, className, options)
        %FROMSTRUCT Reconstruct objects from a struct or struct array.
        %
        % obj = nansen.common.mixin.StructConvertible.fromStruct(S) reconstructs 
        % an object (or array of objects) from the struct (or struct array) S.
        % If S includes a context header with 'ObjectClassName', that class is 
        % used. Otherwise, you must specify 'className'.
        %
        % obj = StructConvertible.fromStruct(S, className) uses the given
        % className if the struct S does not have a context header.
        %
        % Options:
        %   'FailIfContextMissing' (logical, default true) - If true,
        %   an error is raised if no context and no className is
        %   provided. If false, the method returns S as-is if it can't
        %   determine the class.
        %
        % Returns:
        %   obj - The reconstructed object or object array.
        %
        % Example:
        %   S = jsondecode(jsonStr); % Suppose jsonStr came from an earlier toStruct call
        %   newObj = StructConvertible.fromStruct(S);
        %
        % Note: 
        %   Subclasses may implement the fromStruct using the following
        %   template:
        %
        %   methods (Static)
        %       function obj = fromStruct(S)
        %           import nansen.common.mixin.StructConvertible
        %           obj = StructConvertible.fromStruct(S, mfilename('class'));
        %       end
        %   end

            arguments
                S (1,:) struct
                className (1,1) string = missing
                options.FailIfContextMissing (1,1) logical = true
            end

            import nansen.common.mixin.StructConvertible % For recursiveness

            hasContext = isfield(S, 'Context');

            if options.FailIfContextMissing
                if ~hasContext && ismissing(className)
                    error('NANSEN:StructConvertible:ContextNotProvided', ...
                        ['No context provided, cannot convert struct to object ' ...
                        'without knowing which class objects are defined by.'])
                end
            else
                % This case is to allow for recursiveness without requiring
                % the output to be an object, sometimes it might be that the
                % value should just remain a struct.
                obj = S;
                return
            end
            
            if hasContext
                className = S.ObjectClassName;
                data = S.ObjectProperties;
                numObjects = S.NumObjects;
            else
                data = S;
                numObjects = numel(data);
            end
            
            objectArray = cell(1, numObjects);
            propertyNames = fieldnames(data);

            for iObj = 1:numObjects
                thisObject = feval(className);
                for jProp = 1:numel(propertyNames)
                    thisPropName = propertyNames{jProp};
                    thisPropValue = data(iObj).(thisPropName);
                    if isstruct(thisPropValue) % recursive
                        thisObject.(thisPropName) = ...
                            StructConvertible.fromStruct(thisPropValue, ...
                                'FailIfContextMissing', false);
                    else
                        thisObject.(thisPropName) = thisPropValue;
                    end
                end
                objectArray{iObj} = thisObject;
            end

            obj = [objectArray{:}];
        end
    end
end
