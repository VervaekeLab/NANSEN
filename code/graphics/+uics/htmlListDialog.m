function [result, action, hasResult] = htmlListDialog(mode, listIn, params)
%htmlListDialog Modal uihtml backend for simple list/input dialogs.

    arguments
        mode (1,1) string {mustBeMember(mode, ["list-editor", "input-or-select"])}
        listIn = {}
        params (1,1) struct = struct()
    end

    result = [];
    action = "Close";
    hasResult = false;

    items = normalizeStringList(listIn);
    title = getParam(params, 'Title', '');
    if strlength(string(title)) == 0
        title = getDefaultTitle(mode);
    end

    figureSize = getFigureSize(mode);
    hFigure = uifigure(...
        'Name', char(title), ...
        'MenuBar', 'none', ...
        'NumberTitle', 'off', ...
        'Resize', 'off', ...
        'Visible', 'off', ...
        'WindowStyle', 'modal');
    hFigure.Position(3:4) = figureSize;
    hFigure.Color = getThemeColor(params, 'FigureBgColor', [0.13, 0.13, 0.13]);
    hFigure.UserData = struct(...
        'Action', action, ...
        'Result', result, ...
        'HasResult', hasResult);
    hFigure.CloseRequestFcn = @(src, ~) onDialogClosed(src);

    if isfield(params, 'ReferencePosition') && ~isempty(params.ReferencePosition)
        uim.utility.layout.centerObjectInRectangle(hFigure, params.ReferencePosition)
    else
        movegui(hFigure, 'center')
    end

    htmlFile = fullfile(fileparts(mfilename('fullpath')), ...
        'resources', 'html', 'listDialog.html');
    hHtml = uihtml(hFigure, ...
        'HTMLSource', htmlFile, ...
        'Position', [1, 1, figureSize]);
    hHtml.DataChangedFcn = @(src, ~) onHtmlDataChanged(src, hFigure, mode);

    hHtml.Data = struct(...
        'Mode', char(mode), ...
        'Title', char(title), ...
        'Items', {items}, ...
        'ItemName', char(getParam(params, 'ItemName', 'value')), ...
        'BackgroundColor', rgbToHex(getThemeColor(params, 'FigureBgColor', [0.13, 0.13, 0.13])), ...
        'ForegroundColor', rgbToHex(getThemeColor(params, 'FigureFgColor', [0.92, 0.92, 0.92])), ...
        'AccentColor', rgbToHex(getThemeColor(params, 'HeaderMidColor', [0.24, 0.48, 0.72])));

    hFigure.Visible = 'on';
    uiwait(hFigure)

    if isvalid(hFigure)
        dialogState = hFigure.UserData;
        action = string(dialogState.Action);
        result = dialogState.Result;
        hasResult = dialogState.HasResult;
        delete(hFigure)
    end
end

function onHtmlDataChanged(hHtml, hFigure, ~)
    if ~isvalid(hFigure)
        return
    end

    data = hHtml.Data;
    if ~isstruct(data) || ~isfield(data, 'Action')
        return
    end

    action = string(data.Action);
    if strlength(action) == 0
        return
    end

    dialogState = hFigure.UserData;
    dialogState.Action = action;

    switch action
        case "Save"
            dialogState.Result = normalizeStringList(data.Result);
            dialogState.HasResult = true;
        case "Ok"
            dialogState.HasResult = readLogicalField(data, 'HasResult', false);
            if dialogState.HasResult
                dialogState.Result = char(string(data.Result));
            else
                dialogState.Result = [];
            end
        case "Cancel"
            dialogState.Result = [];
            dialogState.HasResult = false;
        otherwise
            return
    end

    hFigure.UserData = dialogState;
    uiresume(hFigure)
end

function onDialogClosed(hFigure)
    if ~isvalid(hFigure)
        return
    end

    dialogState = hFigure.UserData;
    dialogState.Action = "Close";
    dialogState.Result = [];
    dialogState.HasResult = false;
    hFigure.UserData = dialogState;
    uiresume(hFigure)
end

function items = normalizeStringList(value)
    if isempty(value)
        items = {};
    elseif isstring(value)
        items = cellstr(value(:));
    elseif iscell(value)
        items = cellfun(@char, value(:), 'UniformOutput', false);
    else
        items = cellstr(string(value(:)));
    end
    items = reshape(items, 1, []);
end

function value = getParam(params, fieldName, defaultValue)
    if isfield(params, fieldName) && ~isempty(params.(fieldName))
        value = params.(fieldName);
    else
        value = defaultValue;
    end
end

function color = getThemeColor(params, fieldName, defaultColor)
    color = defaultColor;
    if isfield(params, 'Theme') && isstruct(params.Theme) && ...
            isfield(params.Theme, fieldName) && ~isempty(params.Theme.(fieldName))
        color = params.Theme.(fieldName);
    end
end

function hex = rgbToHex(rgb)
    rgb = double(rgb(:)');
    if numel(rgb) < 3
        rgb = [0.13, 0.13, 0.13];
    end
    rgb = rgb(1:3);
    if max(rgb) <= 1
        rgb = round(rgb .* 255);
    end
    rgb = min(max(round(rgb), 0), 255);
    hex = sprintf('#%02X%02X%02X', rgb(1), rgb(2), rgb(3));
end

function tf = readLogicalField(data, fieldName, defaultValue)
    if isfield(data, fieldName)
        tf = logical(data.(fieldName));
    else
        tf = defaultValue;
    end
end

function title = getDefaultTitle(mode)
    switch mode
        case "list-editor"
            title = "Edit List";
        case "input-or-select"
            title = "Select Value";
    end
end

function figureSize = getFigureSize(mode)
    switch mode
        case "list-editor"
            figureSize = [320, 300];
        case "input-or-select"
            figureSize = [320, 330];
    end
end
