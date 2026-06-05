classdef OptionsEditorStub < handle
%OptionsEditorStub Stub options editor for plugin lifecycle tests.
%
%   Provides canned wasCanceled state and a no-op waitfor so tests can
%   drive the options-editor protocol without a real UI.

    properties
        dataEdit
        wasCanceled (1,1) logical = false
        Title = ''
        Callback = []
    end

    events
        AppDestroyed
    end

    methods

        function obj = OptionsEditorStub(dataEdit, wasCanceled)
            obj.dataEdit = dataEdit;
            obj.wasCanceled = wasCanceled;
        end

        function waitfor(~)
        end
    end
end
