classdef HasOptionsManager < handle
%HasOptionsManager Mixin that gives a class an instance-level OptionsManager
%
%   Provides a clean separation between user settings (persistent
%   preferences, saved to file via UserSettings) and method options
%   (algorithm parameters, managed via OptionsManager).
%
%   Intended for use by AppPlugin subclasses that represent an algorithm
%   with parameters. Mix this in alongside AppPlugin to get a dedicated
%   options path that does not go through obj.settings.
%
%   USAGE
%       classdef MyPlugin < applify.mixin.AppPlugin & applify.mixin.HasOptionsManager
%
%       % In assignDefaultOptions:
%       function assignDefaultOptions(obj)
%           obj.OptionsManager = nansen.manage.OptionsManager('myFunction');
%       end
%
%       % Elsewhere: read options
%       opts = obj.Options;
%
%       % Open editor and wait
%       [opts, wasAborted] = obj.editOptions();

    properties
        OptionsManager nansen.manage.OptionsManager
        Modal (1,1) logical = true      % Block execution while options editor is open
        wasAborted = false              % True if options editor was canceled
    end

    properties (Dependent)
        Options
    end

    properties (Access = protected)
        Options_
        hOptionsEditor
    end

    properties (Access = private)
        OptionsEditorDestroyedListener event.listener
    end

    methods % Constructor/destructor

        function obj = HasOptionsManager(options)
        %HasOptionsManager Initialize method options for option-aware plugins.
            arguments
                options = []
            end

            if isempty(options)
                obj.assignDefaultOptions()
            else
                obj.assignOptions(options)
            end
        end

        function delete(obj)
            if ~isempty(obj.hOptionsEditor) && isvalid(obj.hOptionsEditor)
                delete(obj.hOptionsEditor)
            end
            obj.clearOptionsEditorDestroyedListener()
        end
    end

    methods % Set / get methods
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

    methods (Access = public)

        function [options, wasAborted] = editOptions(obj)
        %editOptions Open the options editor and wait for user input

            if ~obj.Modal && nargout
                error('NANSEN:HasOptionsManager:OutputNotAvailable', ...
                    "Modified options are not available in non-modal mode")
            end

            optionsEditor = obj.openOptionsEditor();

            if obj.Modal
                optionsEditor.waitfor()
                obj.onOptionsEditorResumed()

                if nargout
                    if ~isvalid(obj)
                        error('NANSEN:HasOptionsManager:ObjectDeleted', ...
                            "Options are not available because the object was deleted")
                    end
                    options = obj.Options;
                    wasAborted = obj.wasAborted;
                end
            else
                obj.OptionsEditorDestroyedListener = addlistener(optionsEditor, ...
                    'AppDestroyed', @(s, e) obj.resumeOptionsEditor());
            end
        end

        function optionsEditor = openOptionsEditor(obj, callback)
        %openOptionsEditor Open a ui dialog for editing method options.
            if nargin < 2
                callback = [];
            end

            titleStr = obj.getOptionsEditorTitle();

            if ~isempty(obj.OptionsManager)
                optionsEditor = obj.OptionsManager.openOptionsEditor([], obj.Options);
                optionsEditor.Title = titleStr;
                if ~isempty(callback)
                    optionsEditor.Callback = callback;
                end
            elseif isempty(callback)
                optionsEditor = structeditor(obj.Options, 'Title', titleStr);
            else
                optionsEditor = structeditor(obj.Options, ...
                    'Title', titleStr, 'Callback', callback);
            end

            obj.hOptionsEditor = optionsEditor;
        end

        function place(obj, varargin)
            if isempty(obj.hOptionsEditor) || ~isvalid(obj.hOptionsEditor)
                return
            end
            obj.hOptionsEditor.place(varargin{:})
        end

    end

    methods (Access = protected)

        function assignOptions(obj, options)
        %assignOptions Assign non-default options for plugin
            if isa(options, 'struct')
                obj.assignOptionsStruct(options)
            elseif isa(options, 'nansen.manage.OptionsManager')
                obj.OptionsManager = options;
                obj.assignOptionsStruct(obj.OptionsManager.Options)
            else
                error('HasOptionsManager:InvalidOptions', ...
                    'Options must be a struct or nansen.manage.OptionsManager.')
            end
        end

        function assignDefaultOptions(obj) %#ok<MANU>
        %assignDefaultOptions Assign default options. Subclasses may override.
        end

        function assignOptionsStruct(obj, options)
            obj.Options = options;
        end

        function onOptionsEditorResumed(obj)
        %onOptionsEditorResumed Called when the editor closes or is confirmed.
            if isempty(obj.hOptionsEditor) || ~isvalid(obj.hOptionsEditor)
                obj.hOptionsEditor = [];
                obj.clearOptionsEditorDestroyedListener()
                return
            end

            obj.wasAborted = obj.hOptionsEditor.wasCanceled;
            if ~obj.wasAborted
                obj.Options = obj.hOptionsEditor.dataEdit;
            end

            delete(obj.hOptionsEditor)
            obj.hOptionsEditor = [];
            obj.clearOptionsEditorDestroyedListener()

            if ~obj.wasAborted
                obj.onOptionsChanged();
            end
        end

        function onOptionsChanged(obj) %#ok<MANU>
        %onOptionsChanged Called after options are changed via editOptions
        %   Subclasses may override to react to option changes immediately.
        end

        function titleStr = getOptionsEditorTitle(obj)
            titleStr = 'Options Editor';

            if isprop(obj, 'Name')
                propertyName = 'Name';
                titleStr = sprintf('Options Editor (%s)', obj.(propertyName));
            end
        end

    end

    methods (Access = private)

        function resumeOptionsEditor(obj)
        %resumeOptionsEditor Resume after a non-modal options editor closes.
            obj.onOptionsEditorResumed()

            if isvalid(obj)
                obj.clearOptionsEditorDestroyedListener()
            end
        end

        function clearOptionsEditorDestroyedListener(obj)
        %clearOptionsEditorDestroyedListener Delete and clear editor listener.
            if ~isempty(obj.OptionsEditorDestroyedListener) && ...
                    isvalid(obj.OptionsEditorDestroyedListener)
                delete(obj.OptionsEditorDestroyedListener)
            end
            obj.OptionsEditorDestroyedListener = [];
        end

    end

    methods (Static)

        function [opts, cellOfArgs] = splitOptionsArgument(cellOfArgs)
        %splitOptionsArgument Split leading options object from argument list.
            opts = [];

            if numel(cellOfArgs) >= 1
                containsOpts = isa(cellOfArgs{1}, 'struct') || ...
                    isa(cellOfArgs{1}, 'nansen.manage.OptionsManager');

                if containsOpts
                    opts = cellOfArgs{1};
                    cellOfArgs(1) = [];
                end
            end
        end

        function [opts, cellOfArgs] = optionsCheck(cellOfArgs)
        %optionsCheck Backward-compatible name for splitOptionsArgument.
            [opts, cellOfArgs] = applify.mixin.HasOptionsManager.splitOptionsArgument(cellOfArgs);
        end

    end

end
