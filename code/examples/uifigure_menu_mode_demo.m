function uifigure_menu_mode_demo()
%UIFIGURE_MENU_MODE_DEMO Demonstrate live menu modes with uifigure key callbacks.
%
% Run:
%   uifigure_menu_mode_demo
%
% Select a sticky mode using the toolbar or these keys:
%   Shift  : Preview
%   q      : Queue
%   e      : Edit
%   r      : Restart
%   h      : Help
%   Escape : Default

    iconButtonFolder = [ ...
        '/Users/eivihe/Code/MATLAB/General/FEX/icon_button_component', ...
        '/icon_button_component'];
    if exist(iconButtonFolder, 'dir')
        addpath(iconButtonFolder)
    else
        error('Could not find IconButton folder: %s', iconButtonFolder)
    end

    mode = "Default";
    modeNames = ["Default", "Preview", "Queue", "Edit", "Restart", "Help"];
    modeKeys = ["escape", "shift", "q", "e", "r", "h"];

    fig = uifigure( ...
        "Name", "uifigure Menu Mode Demo", ...
        "Position", [100 100 560 380]);

    fig.WindowKeyPressFcn = @onKeyPressed;

    layout = uigridlayout(fig, [3 1]);
    layout.RowHeight = {25, 28, "1x"};
    layout.ColumnWidth = {"1x"};
    layout.Padding = [16 16 0 0];
    layout.RowSpacing = 8;

    header = uigridlayout(layout, [1 2]);
    header.Layout.Row = 1;
    header.ColumnWidth = {"1x", numel(modeNames)*25};
    header.RowHeight = {25};
    header.Padding = [0 0 0 0];
    header.ColumnSpacing = 0;

    toolbar = uigridlayout(header, [1 numel(modeNames)]);
    toolbar.Layout.Row = 1;
    toolbar.Layout.Column = 2;
    toolbar.ColumnWidth = repmat({25}, 1, numel(modeNames));
    toolbar.RowHeight = {25};
    toolbar.Padding = [0 0 0 0];
    toolbar.ColumnSpacing = 0;

    statusLabel = uilabel(layout, ...
        "Text", "Mode: Default. Press q/e/r/h/Shift or use toolbar; Escape resets.");
    statusLabel.Layout.Row = 2;

    logArea = uitextarea(layout, ...
        "Editable", "off", ...
        "Value", {'Selected commands are logged here.'});
    logArea.Layout.Row = 3;

    sessionMenu = uimenu(fig, "Text", "&Session");
    taskItems = matlab.ui.container.Menu.empty(0, 1);
    taskItems(end+1) = addTaskMenuItem(sessionMenu, "Load Data", true);
    taskItems(end+1) = addTaskMenuItem(sessionMenu, "Motion Correct", true);
    taskItems(end+1) = addTaskMenuItem(sessionMenu, "Manual Curation", false);
    taskItems(end+1) = addTaskMenuItem(sessionMenu, "Plot Summary", false);

    modeMenu = uimenu(fig, "Text", "&Mode");
    modeItems = matlab.ui.container.Menu.empty(0, 1);
    modeItems(end+1) = addModeMenuItem(modeMenu, "Default");
    modeItems(end+1) = addModeMenuItem(modeMenu, "Preview");
    modeItems(end+1) = addModeMenuItem(modeMenu, "Queue");
    modeItems(end+1) = addModeMenuItem(modeMenu, "Edit");
    modeItems(end+1) = addModeMenuItem(modeMenu, "Restart");
    modeItems(end+1) = addModeMenuItem(modeMenu, "Help");

    modeButtons = IconButton.empty(0, 1);
    iconMap = getModeIconMap(iconButtonFolder);
    for i = 1:numel(modeNames)
        modeButtons(end+1) = addModeToolbarButton( ...
            toolbar, modeNames(i), modeKeys(i), iconMap.(char(modeNames(i))));
        modeButtons(end).Layout.Row = 1;
        modeButtons(end).Layout.Column = i;
    end

    updateMenus()

    function item = addTaskMenuItem(parent, label, isQueueable)
        item = uimenu(parent, ...
            "Text", label, ...
            "MenuSelectedFcn", @onTaskMenuSelected);

        item.UserData = struct( ...
            'BaseText', label, ...
            'IsQueueable', isQueueable);
    end

    function item = addModeMenuItem(parent, label)
        item = uimenu(parent, ...
            "Text", label, ...
            "MenuSelectedFcn", @(~, ~) setMode(label));
    end

    function button = addModeToolbarButton(parent, label, keyName, svgPath)
        button = IconButton(parent, ...
            "SVGSource", svgPath, ...
            "Width", 25, ...
            "Height", 25, ...
            "Padding", 3, ...
            "CornerRadius", 3, ...
            "BackgroundAlpha_Hover", 0.3);
        button.Tooltip = sprintf('%s (%s)', char(label), char(keyName));
        button.UserData = label;
        button.ButtonPushedFcn = @onModeButtonPushed;
    end

    function onKeyPressed(~, event)
        switch string(event.Key)
            case "escape"
                setMode("Default")
            case "shift"
                setMode("Preview")
            case "q"
                setMode("Queue")
            case "e"
                setMode("Edit")
            case "r"
                setMode("Restart")
            case "h"
                setMode("Help")
        end
    end

    function onModeButtonPushed(src, ~)
        selectedMode = string(src.UserData);
        if selectedMode == mode && selectedMode ~= "Default"
            setMode("Default")
        else
            setMode(selectedMode)
        end
        refocusFigure()
    end

    function setMode(newMode)
        newMode = string(newMode);
        if mode == newMode
            return
        end

        mode = newMode;
        updateMenus()
    end

    function updateMenus()
        statusLabel.Text = "Mode: " + mode ...
            + ". Press q/e/r/h/Shift or use toolbar; Escape resets.";

        for i = 1:numel(taskItems)
            item = taskItems(i);
            data = item.UserData;

            item.Text = data.BaseText + modeSuffix(mode);
            item.Enable = "on";

            if mode == "Queue" && ~data.IsQueueable
                item.Enable = "off";
            end
        end

        for i = 1:numel(modeItems)
            if string(modeItems(i).Text) == mode
                modeItems(i).Checked = "on";
            else
                modeItems(i).Checked = "off";
            end
        end

        for i = 1:numel(modeButtons)
            buttonMode = string(modeButtons(i).UserData);
            if buttonMode == mode
                modeButtons(i).Color = "#0072BD";
                modeButtons(i).BackgroundColor = [0.86 0.93 0.98];
            else
                modeButtons(i).Color = "#5F6368";
                modeButtons(i).BackgroundColor = [0.94 0.94 0.94];
            end
        end
        modeItems(1).Parent.Text = sprintf("Mode (%s)", mode);
    end

    function suffix = modeSuffix(currentMode)
        switch currentMode
            case "Default"
                suffix = "";
            case "Preview"
                suffix = " ...";
            case "Queue"
                suffix = " (q)";
            case "Edit"
                suffix = " (e)";
            case "Restart"
                suffix = " (r)";
            case "Help"
                suffix = " (h)";
            otherwise
                suffix = "";
        end
    end

    function onTaskMenuSelected(src, ~)
        data = src.UserData;
        newEntry = sprintf('%s selected in %s mode', ...
            char(data.BaseText), char(mode));
        logArea.Value = [{newEntry}; logArea.Value(:)];

        setMode("Default")
        refocusFigure()
    end

    function refocusFigure()
        try
            focus(fig)
        catch
            % focus is available only for some UI targets/MATLAB releases.
        end
    end

    function iconMap = getModeIconMap(componentFolder)
        iconFolder = fullfile(componentFolder, 'resources', 'icons');
        bicolorFolder = fullfile(iconFolder, 'bicolor');

        iconMap = struct();
        iconMap.Default = fullfile(bicolorFolder, '001_-home-page.svg');
        iconMap.Preview = fullfile(bicolorFolder, '001_-search.svg');
        iconMap.Queue = fullfile(bicolorFolder, '001_-forward.svg');
        iconMap.Edit = fullfile(bicolorFolder, '001_-detail-page.svg');
        iconMap.Restart = fullfile(iconFolder, 'play-113.svg');
        iconMap.Help = fullfile(bicolorFolder, '001_-information.svg');
    end
end
