classdef ModalMethodPreviewController < handle
%ModalMethodPreviewController Behavioral mixin for modal edit/preview/run workflows
%
%   Provides the lifecycle for plugins that:
%     1. Open a modal options editor (edit)
%     2. Show a live preview while the editor is open (preview)
%     3. Run the method when the editor is confirmed (run)
%     4. Destroy themselves when finished (destroy)
%
%   Subclasses should override:
%     - assignDefaultOptions  - set the default method options
%     - openControlPanel      — set up preview state, then call editOptions
%     - run                   — execute the method
%     - onOptionsChanged      - react to live option changes in the editor
%     - onOptionsEditorClosed — clean up preview state when editor closes
%
%   This class is a behavioral mixin, not the primary plugin base class.
%   Concrete plugins should combine it with a single AppPlugin-derived
%   superclass such as imviewer.ImviewerPlugin.

    properties
        RunMethodOnFinish (1,1) logical = true  % Run method when editor is confirmed
        DestroyOnFinish   (1,1) logical = true  % Destroy plugin after run
        Modal             (1,1) logical = true  % Block execution while editor is open
    end

    properties (Dependent)
        Options
    end

    properties (Access = protected)
        Options_ struct = struct.empty
        hOptionsEditor
    end
    properties
        wasAborted = false
    end

    methods (Access = public)

        function openControlPanel(obj)
        %openControlPanel Open the options editor. Subclasses may override
        % to set up preview state before calling editOptions.
            obj.editOptions()
        end

        function editOptions(obj)
        %editOptions Open the options editor and wait (if modal).
            optionsEditor = obj.openOptionsEditor();
            if obj.Modal
                optionsEditor.waitfor()
                obj.onOptionsEditorResumed()
            else
                addlistener(optionsEditor, 'AppDestroyed', ...
                    @(s, e) obj.onOptionsEditorResumed);
            end
        end

        function optionsEditor = openOptionsEditor(obj)
        %openOptionsEditor Open the ui dialog for editing method options.
            titleStr = sprintf('Options Editor (%s)', obj.Name);
            if ~isempty(obj.OptionsManager)
                optionsEditor = obj.OptionsManager.openOptionsEditor([], obj.getCurrentOptions());
                optionsEditor.Title = titleStr;
                optionsEditor.Callback = @obj.onOptionsChanged;
            else
                optionsEditor = structeditor(obj.getCurrentOptions(), ...
                    'Title', titleStr, 'Callback', @obj.onOptionsChanged);
            end
            obj.relocatePrimaryApp(optionsEditor)
            obj.hOptionsEditor = optionsEditor;
            addlistener(obj, 'ObjectBeingDestroyed', @(s,e) delete(optionsEditor));
        end

        function place(obj, varargin)
            obj.hOptionsEditor.place(varargin{:})
        end

    end

    methods (Access = protected)

        function onOptionsEditorResumed(obj)
        %onOptionsEditorResumed Called when the editor closes or is confirmed.
            if isempty(obj.hOptionsEditor) || ~isvalid(obj.hOptionsEditor)
                obj.hOptionsEditor = [];
                return
            end
            if ~obj.hOptionsEditor.wasCanceled
                obj.setCurrentOptions(obj.hOptionsEditor.dataEdit);
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

        function relocatePrimaryApp(obj, hPlugin, direction)
        %relocatePrimaryApp Shift app and plugin windows so they do not overlap.
            if nargin < 3; direction = 'horizontal'; end
            figPos(1,:) = getpixelposition(hPlugin.Figure);
            figPos(2,:) = getpixelposition(obj.PrimaryApp.Figure);
            hFig = [hPlugin.Figure, obj.PrimaryApp.Figure];
            switch direction
                case 'horizontal'; figPos_ = figPos(:, [1,3]); dim = 1;
                case 'vertical';   figPos_ = figPos(:, [2,4]); dim = 2;
            end
            screenPos = uim.utility.getCurrentScreenSize(obj.PrimaryApp.Figure);
            [~, idx] = sort(figPos_(:, 1));
            figPos = figPos(idx, :);
            hFig = hFig(idx);
            [x, ~] = uim.utility.layout.subdividePosition(min(figPos(:,1)), ...
                screenPos(dim+2), figPos_(:,2), 20);
            for i = 1:2
                hFig(i).Position(dim) = x(i);
            end
        end

        function options = getCurrentOptions(obj)
        %getCurrentOptions Return the current method options.
            options = obj.Options;
        end

        function setCurrentOptions(obj, options)
        %setCurrentOptions Assign the current method options.
            obj.Options = options;
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

    methods
        function set.Options(obj, options)
            obj.Options_ = options;
        end

        function options = get.Options(obj)
            if ~isempty(obj.Options_)
                options = obj.Options_;
            elseif ~isempty(obj.OptionsManager)
                options = obj.OptionsManager.Options;
            else
                options = struct.empty;
            end
        end
    end
end
