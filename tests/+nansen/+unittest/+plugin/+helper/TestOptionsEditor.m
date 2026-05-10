classdef TestOptionsEditor < handle
%TestOptionsEditor Minimal options editor test double.

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

        function obj = TestOptionsEditor(dataEdit, wasCanceled)
            obj.dataEdit = dataEdit;
            obj.wasCanceled = wasCanceled;
        end

        function waitfor(~)
        end
    end
end
