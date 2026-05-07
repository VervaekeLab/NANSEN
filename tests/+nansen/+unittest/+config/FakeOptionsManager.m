classdef FakeOptionsManager < handle

    properties
        OptionsName char = 'Preset A'
        DefaultName char = 'Preset A'
        SavedOptions
        SavedName char = ''
        SaveCustomOptionsCallCount (1,1) double = 0
        SetDefaultCallCount (1,1) double = 0
    end

    properties (Access = private)
        PresetMap containers.Map
        CustomMap containers.Map
        ModifiedMap containers.Map
    end

    properties (Dependent)
        PresetOptionNames
        CustomOptionNames
        EditedOptionNames
        AllOptionNames
    end

    methods
        function obj = FakeOptionsManager()
            obj.PresetMap = containers.Map();
            obj.CustomMap = containers.Map();
            obj.ModifiedMap = containers.Map();

            obj.PresetMap('Preset A') = struct('Value', 1);
            obj.PresetMap('Preset B') = struct('Value', 2);
            obj.CustomMap('Custom A') = struct('Value', 10);
        end

        function names = get.PresetOptionNames(obj)
            names = obj.PresetMap.keys();
        end

        function names = get.CustomOptionNames(obj)
            names = obj.CustomMap.keys();
        end

        function names = get.EditedOptionNames(obj)
            names = obj.ModifiedMap.keys();
        end

        function names = get.AllOptionNames(obj)
            names = [obj.PresetOptionNames, obj.CustomOptionNames];
        end

        function options = getOptions(obj, optionsName)
            optionsName = char(optionsName);
            if obj.PresetMap.isKey(optionsName)
                options = obj.PresetMap(optionsName);
            elseif obj.CustomMap.isKey(optionsName)
                options = obj.CustomMap(optionsName);
            else
                error('FakeOptionsManager:UnknownOptions', ...
                    'Unknown options set "%s".', optionsName)
            end
        end

        function appendModifiedOptions(obj, opts, name)
            obj.ModifiedMap(char(name)) = opts;
        end

        function removeModifiedOptions(obj, name)
            name = char(name);
            if obj.ModifiedMap.isKey(name)
                obj.ModifiedMap.remove(name);
            end
        end

        function options = getModifiedOptions(obj, name)
            options = obj.ModifiedMap(char(name));
        end

        function resetModifiedOptions(obj)
            obj.ModifiedMap = containers.Map();
        end

        function tf = isModified(obj, name)
            tf = obj.ModifiedMap.isKey(char(name));
        end

        function givenName = saveCustomOptions(obj, opts, name)
            if nargin < 3 || isempty(name)
                name = 'Saved Custom';
            end

            givenName = char(name);
            obj.SaveCustomOptionsCallCount = obj.SaveCustomOptionsCallCount + 1;
            obj.SavedOptions = opts;
            obj.SavedName = givenName;
            obj.CustomMap(givenName) = opts;
        end

        function setDefault(obj, optionsName)
            obj.SetDefaultCallCount = obj.SetDefaultCallCount + 1;
            obj.DefaultName = char(optionsName);
        end

        function name = getPreferredOptionsName(obj)
            name = obj.DefaultName;
        end
    end

    methods (Static)
        function names = formatPresetNames(names)
            names = cellfun(@(name) sprintf('[%s]', name), names, 'UniformOutput', false);
        end

        function name = formatDefaultName(name)
            if iscell(name)
                name = cellfun(@(n) strcat(n, ' (Default)'), name, 'UniformOutput', false);
            else
                name = strcat(name, ' (Default)');
            end
        end

        function names = formatEditedNames(names)
            % Modified names already include their marker.
        end
    end
end
