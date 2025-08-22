classdef AbstractPluginSpec < matlab.mixin.SetGet % Todo: Inherit from StructAdapter

    properties
        ImplementationType (1,1) nansen.internal.plugin.enum.ImplementationType = "Function"
    end

    properties (Abstract, Constant)
        TYPE
        VERSION
    end
       
    properties (Abstract, Access = protected)
        RequiredProperties (1,:) string;
    end

    methods
        function obj = AbstractPluginSpec(options)
            % AbstractPluginSpec Construct a new AbstractPluginSpec object
            %
            %   obj = AbstractPluginSpec() creates a object with default values.
            %
            %   obj = AbstractPluginSpec(options) initializes properties from
            %   the given struct. Each field in the struct must correspond to
            %   a property name.
            arguments
                options (1,1) struct = struct
            end
            obj.set(options)
            obj.checkRequired()
        end
    end

    methods
        function nvPairs = toCell(obj)
            % toCell Convert properties to name-value pairs
            %
            %   nvPairs = obj.toCell() returns a 1-by-2N cell array containing
            %   the property names and values of the object, suitable for use
            %   as name-value pair arguments in other functions.
            %
            %   Example:
            %     args = opts.toCell();
            %     someFunction(args{:});
            %
            propNames = properties(obj);
            propValues = obj.get(propNames);
            nvPairs = cell(1, numel(propNames)*2);
            [nvPairs(:)] = [propNames, propValues']';
        end

        function S = toStruct(obj)
            C = obj.toCell();
            props = struct(C{:});
            props = rmfield(props, 'ImplementationType');
            props = rmfield(props, {'TYPE', 'VERSION'});

            S = struct();
            S.x_type = obj.TYPE;
            S.x_version = obj.VERSION;
            S.Properties = props;
        end

        function jsonStr = toJson(obj)
            S = obj.toStruct();
            jsonStr = jsonencode(S, 'PrettyPrint', true);
            jsonStr = obj.fixCustomJsonPropNames(jsonStr);
        end
    end

    methods (Access = protected)
        function jsonStr = fixCustomJsonPropNames(~, jsonStr)
            jsonStr = strrep(jsonStr, '"x_type"', '"_type"');
            jsonStr = strrep(jsonStr, '"x_version"', '"_version"');
        end
    end

    methods (Access = private)
        function checkRequired(obj)
            isPresent = false(1, numel(obj.RequiredProperties));
            for i = 1:numel(obj.RequiredProperties)
                currentProp = obj.RequiredProperties(i);
                isPresent(i) = ~ismissing(obj.(currentProp));
            end
            if any(~isPresent)
                missingProps = obj.RequiredProperties(~isPresent);
                ME = MException(...
                    'NANSEN:Plugin:MissingRequiredProperties', ...
                    ['The following required properties are missing for ', ...
                    'plugin of type %s:\n%s'], obj.TYPE, ...
                    nansen.util.text.strArrayToBulletList( missingProps ) );
                throwAsCaller(ME)
            end
        end
    end
end
