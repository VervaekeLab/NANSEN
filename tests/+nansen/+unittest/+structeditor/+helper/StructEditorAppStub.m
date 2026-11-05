classdef StructEditorAppStub < handle
%StructEditorAppStub Stub of structeditor.StructEditorApp for tests without StructEditor.
%
%   Provides the structeditor.StructEditorApp members that NANSEN calls:
%   Data, OriginalData, FinishState, Title, IsModal, waitfor, replaceData,
%   getPlugin and getAttachmentContainer.
%
%   waitfor returns at once and sets FinishState to FinishStateOnWait, as
%   StructEditorApp does when the user presses Ok ("Finished"), presses
%   Cancel ("Canceled") or closes the window (""). With DeleteOnWait set to
%   true, waitfor also deletes the stub, as StructEditorApp deletes itself
%   on Ok or Cancel when CloseOnExit is true.
%
%   replaceData sets both Data and OriginalData, as in StructEditorApp.
%
%   getAttachmentContainer("header") returns a panel created in Parent. A
%   Plugin is attached on construction when Parent is given, as
%   StructEditorApp attaches its plugins on construction.

    properties
        Data
        Title (1,1) string = ""
        IsModal (1,1) logical = false
    end

    properties (SetAccess = private)
        OriginalData
        FinishState (1,1) string = ""
        Plugins (1,:) cell = {}
    end

    properties (Access = private)
        FinishStateOnWait (1,1) string
        DeleteOnWait (1,1) logical
        HeaderPanel
    end

    methods
        function obj = StructEditorAppStub(data, options)
            arguments
                data
                options.FinishStateOnWait (1,1) string ...
                    {mustBeMember(options.FinishStateOnWait, ["", "Finished", "Canceled"])} = "Finished"
                options.DeleteOnWait (1,1) logical = false
                options.Parent = []
                options.Plugin = []
            end

            obj.Data = data;
            obj.OriginalData = data;
            obj.FinishStateOnWait = options.FinishStateOnWait;
            obj.DeleteOnWait = options.DeleteOnWait;

            if ~isempty(options.Parent)
                obj.HeaderPanel = uipanel(options.Parent, 'BorderType', 'none');
            end

            if ~isempty(options.Plugin)
                obj.Plugins = {options.Plugin};
                if ~isempty(obj.HeaderPanel)
                    options.Plugin.attach(obj)
                end
            end
        end

        function delete(obj)
            if ~isempty(obj.HeaderPanel) && isvalid(obj.HeaderPanel)
                delete(obj.HeaderPanel)
            end
        end

        function waitfor(obj)
            obj.FinishState = obj.FinishStateOnWait;
            if obj.DeleteOnWait
                delete(obj)
            end
        end

        function replaceData(obj, data)
            obj.Data = data;
            obj.OriginalData = data;
        end

        function plugin = getPlugin(obj, className)
            plugin = [];
            for i = 1:numel(obj.Plugins)
                if isa(obj.Plugins{i}, className)
                    plugin = obj.Plugins{i};
                    return
                end
            end
        end

        function container = getAttachmentContainer(obj, location)
            arguments
                obj
                location (1,1) string
            end

            if location ~= "header"
                error('StructEditorAppStub:UnsupportedLocation', ...
                    'The stub provides only the "header" container, not "%s".', location)
            end
            container = obj.HeaderPanel;
        end
    end
end
