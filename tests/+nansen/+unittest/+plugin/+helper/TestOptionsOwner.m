classdef TestOptionsOwner < applify.mixin.HasOptionsManager
%TestOptionsOwner Test double for option-owner lifecycle tests.

    properties
        Editor
        OptionsChangedCount (1,1) double = 0
    end

    methods

        function obj = TestOptionsOwner(options)
            obj@applify.mixin.HasOptionsManager(options)
            obj.Modal = false;
        end

        function optionsEditor = openOptionsEditor(obj, ~)
            optionsEditor = obj.Editor;
            obj.hOptionsEditor = optionsEditor;
        end
    end

    methods (Access = protected)

        function onOptionsChanged(obj, varargin) %#ok<INUSD>
            obj.OptionsChangedCount = obj.OptionsChangedCount + 1;
        end
    end
end
