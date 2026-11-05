function hApp = structeditor(varargin)
%STRUCTEDITOR Open app to edit the values of a struct
%   Structeditor is an app for viewing and editing fields of a struct
%
%   hApp = structeditor(S, Name, Value) opens the struct S for editing and
%   returns the app. S can also be a cell array of structs, which the app
%   shows as separate pages.
%
%   structeditor opens structeditor.StructEditorApp from the StructEditor
%   toolbox when nansen.util.useModernStructEditor returns true and the
%   call meets both of these conditions:
%     - S is a scalar struct or a nonempty cell array of scalar structs.
%     - Every name-value argument is one of Title, Prompt, Name,
%       LabelPosition, CustomFigureSize, Callback, OptionsManager,
%       AdjustFigureSize and ReferencePosition.
%   StructEditorApp accepts AdjustFigureSize and ReferencePosition and
%   ignores them. An OptionsManager is passed to StructEditorApp as a
%   nansen.manage.OptionsManagerPlugin, which shows the options sets in
%   the header of the app.
%
%   Every other call opens the legacy app, structeditor.App. This includes
%   calls with a parent container as the first input and calls with
%   name-value arguments such as Visible, ValueChangedFcn or TestFunc.
%
%   See also structeditor.App, nansen.util.useModernStructEditor

    if nargin > 0 && canUseModernEditor(varargin)
        hApp = openModernEditor(varargin{1}, varargin(2:end));
    else
        hApp = structeditor.App(varargin{:});
    end

    if ~nargout
        clear hApp
    end
end

function tf = canUseModernEditor(args)
%canUseModernEditor True when StructEditorApp supports the data and options of a call.
    arguments
        args (1,:) cell
    end

    tf = isModernEditorData(args{1}) ...
        && hasOnlyModernEditorOptions(args(2:end)) ...
        && nansen.util.useModernStructEditor();
end

function tf = isModernEditorData(data)
%isModernEditorData True for a scalar struct or a nonempty cell array of scalar structs.
    isScalarStruct = @(value) isstruct(value) && isscalar(value);

    if iscell(data)
        tf = ~isempty(data) && all(cellfun(isScalarStruct, data(:)));
    else
        tf = isScalarStruct(data);
    end
end

function tf = hasOnlyModernEditorOptions(nameValueArgs)
%hasOnlyModernEditorOptions True when every name-value argument is supported by StructEditorApp.
    arguments
        nameValueArgs (1,:) cell
    end

    modernEditorOptions = ["Title", "Prompt", "Name", "LabelPosition", ...
        "CustomFigureSize", "Callback", "OptionsManager", ...
        "AdjustFigureSize", "ReferencePosition"];

    if mod(numel(nameValueArgs), 2) ~= 0
        tf = false;
        return
    end

    names = nameValueArgs(1:2:end);
    isName = cellfun(@(name) (ischar(name) && isrow(name)) ...
        || (isstring(name) && isscalar(name)), names);

    tf = all(isName) ...
        && all(ismember(lower(string(names)), lower(modernEditorOptions)));
end

function editor = openModernEditor(data, nameValueArgs)
%openModernEditor Open StructEditorApp, passing an OptionsManager as a plugin.
    arguments
        data
        nameValueArgs (1,:) cell
    end

    [nameValueArgs, optionsManager] = popNameValue(nameValueArgs, "OptionsManager");
    if ~isempty(optionsManager)
        plugin = nansen.manage.OptionsManagerPlugin(optionsManager);
        nameValueArgs = [nameValueArgs, {'Plugin', plugin}];
    end

    editor = structeditor.StructEditorApp(data, nameValueArgs{:});
end

function [nameValueArgs, value] = popNameValue(nameValueArgs, name)
%popNameValue Remove a name-value argument from a list and return its last value.
    arguments
        nameValueArgs (1,:) cell
        name (1,1) string
    end

    pairIndex = find(strcmpi(string(nameValueArgs(1:2:end)), name));
    if isempty(pairIndex)
        value = [];
        return
    end

    value = nameValueArgs{2*pairIndex(end)};
    nameValueArgs([2*pairIndex-1, 2*pairIndex]) = [];
end
