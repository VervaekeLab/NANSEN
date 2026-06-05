classdef OptionsOwnerSpy < applify.mixin.HasOptionsManager
%OptionsOwnerSpy Spy for options-owner lifecycle tests.
%
%   Records OptionsChangedCount so tests can assert how many times options
%   changes were fired without a real UI.

    properties
        Editor
        OptionsChangedCount (1,1) double = 0
    end

    methods

        function obj = OptionsOwnerSpy(options)
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
