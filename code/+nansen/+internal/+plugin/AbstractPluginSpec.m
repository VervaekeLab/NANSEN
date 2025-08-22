classdef AbstractPluginSpec < matlab.mixin.SetGet

    properties
        ImplementationType (1,1) nansen.internal.plugin.enum.ImplementationType = "Function"
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
    end
end
