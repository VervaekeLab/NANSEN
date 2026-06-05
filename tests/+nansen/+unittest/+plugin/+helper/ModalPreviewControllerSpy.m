classdef ModalPreviewControllerSpy < applify.mixin.ModalMethodPreviewController
%ModalPreviewControllerSpy Spy for modal preview controller lifecycle tests.
%
%   Records WasRun and EditorClosedCount so tests can assert on call-through
%   behaviour without a real UI editor.

    properties
        Editor
        WasRun (1,1) logical = false
        EditorClosedCount (1,1) double = 0
    end

    methods

        function obj = ModalPreviewControllerSpy(options)
            obj@applify.mixin.ModalMethodPreviewController(options)
            obj.DestroyOnFinish = false;
        end

        function optionsEditor = openOptionsEditor(obj)
            optionsEditor = obj.Editor;
            obj.hOptionsEditor = optionsEditor;
        end

        function run(obj)
            obj.WasRun = true;
        end
    end

    methods (Access = protected)

        function onOptionsEditorClosed(obj)
            obj.EditorClosedCount = obj.EditorClosedCount + 1;
        end
    end
end
