classdef (Abstract) ModalMethodPreviewController < applify.mixin.HasOptionsManager
%ModalMethodPreviewController Behavioral mixin for modal edit/preview/run workflows
%
%   Provides the lifecycle for plugins that:
%     1. Open a modal options editor (edit)
%     2. Show a live preview while the editor is open (preview)
%     3. Run the method when the editor is confirmed (run)
%     4. Destroy themselves when finished (destroy)
%
%   Subclasses must override:
%     - run                   — execute the method
%
%   Subclasses may/should override:
%     - assignDefaultOptions  - set the default method options
%     - openControlPanel      — set up preview state, then call editOptions
%     - onOptionsChanged      - react to live option changes in the editor
%     - onOptionsEditorClosed — clean up preview state when editor closes
%
%   Subclassing guidelines
%   - This class is a behavioral mixin, not the primary plugin base class.
%   - Concrete plugins should combine it with a single AppPlugin-derived
%     superclass such as imviewer.ImviewerPlugin.
%   - Host-app behavior belongs in the concrete plugin or an app-specific
%     superclass.

    properties
        RunMethodOnFinish (1,1) logical = true  % Run method when editor is confirmed
        DestroyOnFinish   (1,1) logical = true  % Destroy plugin after run
    end

    methods (Abstract)
        run(obj)
    end

    methods (Access = public)

        function obj = ModalMethodPreviewController(options)
        %ModalMethodPreviewController Initialize modal method options.
            arguments
                options = []
            end

            obj@applify.mixin.HasOptionsManager(options)
        end

        function openControlPanel(obj)
        %openControlPanel Open the options editor. Subclasses may override
        % to set up preview state before calling editOptions.
            obj.editOptions()
        end

        function optionsEditor = openOptionsEditor(obj)
        %openOptionsEditor Open the ui dialog for editing method options.
            optionsEditor = openOptionsEditor@applify.mixin.HasOptionsManager(...
                obj, @obj.onOptionsChanged);
        end

    end

    methods (Access = protected)

        function onOptionsEditorResumed(obj)
        %onOptionsEditorResumed Called when the editor closes or is confirmed.

            if ~isvalid(obj)
                % Abort, controller might be used by a plugin that
                % was deleted by closing an app.
                return
            end

            if isempty(obj.hOptionsEditor) || ~isvalid(obj.hOptionsEditor)
                obj.hOptionsEditor = [];
                return
            end

            if ~obj.hOptionsEditor.wasCanceled
                obj.Options = obj.hOptionsEditor.dataEdit;
            end

            obj.wasAborted = obj.hOptionsEditor.wasCanceled;
            delete(obj.hOptionsEditor)

            obj.hOptionsEditor = [];
            obj.onOptionsEditorClosed()

            if ~obj.wasAborted && obj.RunMethodOnFinish
                obj.run()
            end
            if obj.DestroyOnFinish
                delete(obj)
            end
        end

        function onOptionsEditorClosed(obj) %#ok<MANU>
        %onOptionsEditorClosed Called just before run/destroy. Subclasses
        % override to clean up preview state (e.g. delete grid overlays).
        end

        function onOptionsChanged(obj, name, value)
        %onOptionsChanged Called when the options editor changes a value.
            obj.updateOptionValue(name, value)
        end

        function updateOptionValue(obj, name, value)
            superFields = fieldnames(obj.Options);

            for i = 1:numel(superFields)
                thisField = superFields{i};
                if isfield(obj.Options.(thisField), name)
                    obj.Options.(thisField).(name) = value;
                end
            end
        end
    end

end
