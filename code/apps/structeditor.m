function hApp = structeditor(varargin)
%STRUCTEDITOR Open app to edit the values of a struct
%   Structeditor is an app for viewing and editing fields of a struct
%
%   For more detailed information:
%   See also structeditor.App

    [varargin, forceLegacy] = popRouterOptions(varargin);

    if nargin == 0
        hApp = structeditor.App();
    elseif useLegacyStructEditor(forceLegacy, varargin{:})
        hApp = structeditor.App(varargin{:});
    else
        varargin = prepareModernStructEditorInputs(varargin);
        hApp = structeditor.StructEditorApp(varargin{:});
    end
    
    if ~nargout
        clear hApp
    end
end

function tf = useLegacyStructEditor(forceLegacy, varargin)

    tf = forceLegacy;
    if tf; return; end

    if isMATLABReleaseOlderThan("R2025a")
        tf = true;
        return
    end

    if exist("structeditor.StructEditorApp", "class") ~= 8
        tf = true;
        return
    end

    if hasParentHandle(varargin{:})
        tf = true;
        return
    end

    if hasNameValueOption(varargin, "showPresetInHeader") && ...
            ~hasNameValueOption(varargin, "OptionsManager")
        tf = true;
        return
    end

    if hasNameValueOption(varargin, "OptionsManager") && ...
            exist("nansen.manage.OptionsManagerPlugin", "class") ~= 8
        tf = true;
    end
end

function tf = hasParentHandle(varargin)
    tf = ~isempty(varargin) && ...
        (isa(varargin{1}, "matlab.ui.container.Panel") || ...
        isa(varargin{1}, "matlab.ui.container.Tab") || ...
        isa(varargin{1}, "matlab.ui.Figure"));
end

function tf = hasNameValueOption(args, names)
    tf = false;
    if isempty(args); return; end

    firstNameValueIndex = 2;
    if hasParentHandle(args{:})
        firstNameValueIndex = 3;
    end

    for i = firstNameValueIndex:2:numel(args)
        if ischar(args{i}) || isstring(args{i})
            if any(strcmpi(string(args{i}), names))
                tf = true;
                return
            end
        end
    end
end

function [args, forceLegacy] = popRouterOptions(args)
    forceLegacy = false;
    removeIdx = [];

    firstNameValueIndex = 2;
    if hasParentHandle(args{:})
        firstNameValueIndex = 3;
    end

    for i = firstNameValueIndex:2:numel(args)
        if ~(ischar(args{i}) || isstring(args{i}))
            continue
        end

        if any(strcmpi(string(args{i}), ["ForceLegacy", "UseLegacyStructEditor"]))
            if i < numel(args)
                forceLegacy = logical(args{i+1});
                removeIdx = [i, i+1];
            end
            break
        end
    end

    args(removeIdx) = [];
end

function args = prepareModernStructEditorInputs(args)
    [args, optionsManager] = popNameValue(args, "OptionsManager");
    [args, ~] = popNameValue(args, "showPresetInHeader");

    if ~isempty(optionsManager)
        plugin = nansen.manage.OptionsManagerPlugin(optionsManager);
        args = [args, {'Plugin', plugin}];
    end
end

function [args, value] = popNameValue(args, name)
    value = [];
    removeIdx = [];

    firstNameValueIndex = 2;
    if hasParentHandle(args{:})
        firstNameValueIndex = 3;
    end

    for i = firstNameValueIndex:2:numel(args)
        if ~(ischar(args{i}) || isstring(args{i}))
            continue
        end

        if strcmpi(string(args{i}), name) && i < numel(args)
            value = args{i+1};
            removeIdx = [i, i+1];
            break
        end
    end

    args(removeIdx) = [];
end
