classdef Preferences < matlab.mixin.CustomDisplay & handle
%Preferences Abstract class for defining preferences that are saved to disk
%
%   Subclasses should implement a PreferenceGroupName, which will be used
%   for display and for filename when saving file.
%
%   Each preference value should be implemented as a property belonging to
%   a public property block with no attributes.
%
%   Important: Any implementation of this class should make its constructor
%   private, and the getSingleton method should be used to get a singleton
%   instance.

%   Todo: Link/reference to package, class or function which preferences
%   belong to

    properties (Abstract, Hidden, Constant)
        PreferenceGroupName
    end

    properties (Dependent, Access = private)
        Filename
    end

    properties (SetAccess = immutable, GetAccess = protected)
        FileName_   % If anything else than the default file name should be used
    end

    methods % Methods which subclasses can override.
        function propertyNames = getPropertiesToHide(obj)
        %getPropertiesToHide Get a list of properties to hide from display
        % 
        %   propertyNames = getPropertiesToHide(obj) return a cell array of
        %   character vectors with name of properties to hide from display

            % The purpose of this method is conditionally hide preferences
            % that might only be relevant in certain contexts.

            propertyNames = {};
        end
    end
    
    methods (Static, Hidden) % Get singleton instance 

        function obj = getSingleton(className)
        %getSingleton Get singleton instance of class

            persistent objStore

            if isempty(objStore)
                objStore = containers.Map;
                %objStore = bot.internal.Preferences();
            end

            if isKey(objStore, className)
                obj = objStore(className);
            else
                obj = feval(className);
                objStore(className) = obj;
            end
        end
    end

    methods (Access = protected) % Constructor

        function obj = Preferences(fileName)

            if nargin >= 1 && ~isempty(fileName)
                obj.FileName_ = fileName;
            end

            thisClassName = mfilename('class');
            persistent objStore

            if isempty(objStore)
                objStore = containers.Map;
            end

            if isKey(objStore, thisClassName)
                obj = objStore(thisClassName);
            else

                if isfile(obj.Filename)
                    S = load(obj.Filename, 'preferences');
                    obj.fromStruct(S.preferences);
                end

                objStore(thisClassName) = obj;
            end
        end

        function save(obj)
            preferences = obj.toStruct();
            save(obj.Filename, 'preferences');
        end
    end

    methods
        function filename = get.Filename(obj)
            if ~isempty(obj.FileName_)
                filename = obj.FileName_;
            else
                prefGroupName = obj.PreferenceGroupName;
                prefGroupName = matlab.lang.makeValidName(prefGroupName);
                filename = fullfile(prefdir, sprintf('%sPreferences.mat', prefGroupName));
            end
        end
    end

    methods (Hidden)
        function reset(obj)
            mc = metaclass(obj);

            propertyList = mc.PropertyList( ~[mc.PropertyList.Constant] );
            propertyNames = string( {propertyList.Name} );
            propertyDefaultValues = {propertyList.DefaultValue};

            for i = 1:numel(propertyNames)
                obj.(propertyNames(i)) = propertyDefaultValues{i};
            end

            obj.save()
        end
    end

    methods (Sealed, Hidden) % Overrides subsref

        function varargout = subsasgn(obj, s, value)
        %subsasgn Override subsasgn to save preferences when they change

            numOutputs = nargout;
            varargout = cell(1, numOutputs);
            
            isPropertyAssigned = strcmp(s(1).type, '.') && ...
                any( strcmp(properties(obj), s(1).subs) );
            
            % Use the builtin subsref with appropriate number of outputs
            if numOutputs > 0
                [varargout{:}] = builtin('subsasgn', obj, s, value);
            else
                builtin('subsasgn', obj, s)
            end

            if isPropertyAssigned
                obj.save()
            end
        end
        
        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            n = builtin('numArgumentsFromSubscript', obj, s, indexingContext);
        end
    end

    methods (Access = protected) % Overrides CustomDisplay methods

        function str = getHeader(obj)
            className = class(obj);
            helpLink = sprintf('<a href="matlab:help %s" style="font-weight:bold">%s</a>', className, 'Preferences');
            str = sprintf('%s for the %s: \n', helpLink, obj.PreferenceGroupName);
        end

        function groups = getPropertyGroups(obj)
            propNames = obj.getActivePreferenceGroup();
            
            s = struct();
            for i = 1:numel(propNames)
                s.(propNames{i}) = obj.(propNames{i});
            end

            groups = matlab.mixin.util.PropertyGroup(s);
        end
    end

    methods (Access = private)
        
        function S = toStruct(obj)
            propNames = properties(obj);
            S = struct();
            for i = 1:numel(propNames)
                S.(propNames{i}) = obj.(propNames{i});
            end
        end
                
        function fromStruct(obj, S)
            propNames = fieldnames(S);
            for i = 1:numel(propNames)
                obj.(propNames{i}) = S.(propNames{i});
            end
        end

        function propertyNames = getActivePreferenceGroup(obj)
        %getCurrentPreferenceGroup Get current preference group
        %
        %   This method returns a cell array of names of preferences that
        %   are currently active. Some preference values are dependent on 
        %   the values of other preferences, and will sometimes not have an
        %   effect.
        %
        %   This method is used by the getPropertyGroups that in turn
        %   determines how the preference object will be displayed. The
        %   effect is that dependent preferences are hidden when they are
        %   not active.

            propertyNames = properties(obj);
            
            namesToHide = obj.getPropertiesToHide();

            propertyNames = setdiff(propertyNames, namesToHide, 'stable');
        end
    
    end

end