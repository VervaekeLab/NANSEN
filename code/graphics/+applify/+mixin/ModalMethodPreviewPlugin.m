classdef ModalMethodPreviewPlugin < applify.mixin.AppPlugin
%ModalMethodPreviewPlugin Base for plugins with a modal edit/preview/run workflow
%
%   Provides the lifecycle for plugins that:
%     1. Open a modal options editor (edit)
%     2. Show a live preview while the editor is open (preview)
%     3. Run the method when the editor is confirmed (run)
%     4. Destroy themselves when finished (destroy)
%
%   Subclasses should override:
%     - assignDefaultOptions   — set obj.OptionsManager and obj.settings
%     - openControlPanel       — set up preview state, then call editSettings
%     - run                    — execute the method
%     - onSettingsChanged      — react to live option changes in the editor
%     - onSettingsEditorClosed — clean up preview state when editor closes

    properties
        RunMethodOnFinish (1,1) logical = true  % Run method when editor is confirmed
        DestroyOnFinish   (1,1) logical = true  % Destroy plugin after run
        Modal             (1,1) logical = true  % Block execution while editor is open
    end

    methods (Access = public)

        function openControlPanel(obj)
        %openControlPanel Open the options editor. Subclasses may override
        % to set up preview state before calling editSettings.
            obj.editSettings()
        end

        function editSettings(obj)
        %editSettings Open the options editor and wait (if modal).
            sEditor = obj.openSettingsEditor();
            if obj.Modal
                sEditor.waitfor()
                obj.onSettingsEditorResumed()
            else
                addlistener(sEditor, 'AppDestroyed', ...
                    @(s, e) obj.onSettingsEditorResumed);
            end
        end

        function sEditor = openSettingsEditor(obj)
        %openSettingsEditor Open the ui dialog for editing options/settings.
            titleStr = sprintf('Options Editor (%s)', obj.Name);
            if ~isempty(obj.OptionsManager)
                sEditor = obj.OptionsManager.openOptionsEditor();
                sEditor.Title = titleStr;
                sEditor.Callback = @obj.onSettingsChanged;
            else
                sEditor = structeditor(obj.settings, 'Title', titleStr, ...
                    'Callback', @obj.onSettingsChanged);
            end
            obj.relocatePrimaryApp(sEditor)
            obj.hSettingsEditor = sEditor;
            addlistener(obj, 'ObjectBeingDestroyed', @(s,e) delete(sEditor));
        end

        function place(obj, varargin)
            obj.hSettingsEditor.place(varargin{:})
        end

    end

    methods (Access = protected)

        function onSettingsEditorResumed(obj)
        %onSettingsEditorResumed Called when the editor closes or is confirmed.
            if ~isvalid(obj.hSettingsEditor)
                obj.hSettingsEditor = [];
                return
            end
            if ~obj.hSettingsEditor.wasCanceled
                obj.settings_ = obj.hSettingsEditor.dataEdit;
            end
            obj.wasAborted = obj.hSettingsEditor.wasCanceled;
            delete(obj.hSettingsEditor)
            obj.hSettingsEditor = [];
            obj.onSettingsEditorClosed()
            if ~obj.wasAborted && obj.RunMethodOnFinish
                obj.run()
            end
            if obj.DestroyOnFinish
                delete(obj)
            end
        end

        function onSettingsEditorClosed(obj) %#ok<MANU>
        %onSettingsEditorClosed Called just before run/destroy. Subclasses
        % override to clean up preview state (e.g. delete grid overlays).
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

    end
end
