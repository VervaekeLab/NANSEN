classdef MessageDisplay < handle
% MessageDisplay - Class interface for displaying messages to user.

    properties (SetAccess = protected) % Or immutable?
        App = [] % Owning app or figure used for parented modern dialogs.
    end

    properties % Preferences
        FontSize = 14
    end

    methods
        function obj = MessageDisplay(app)
            arguments
                app = []
            end

            obj.App = app;
        end

        function hFigure = inform(obj, message, options)
        % inform - Open a message box with info message
            
            arguments
                obj (1,1) nansen.MessageDisplay
                message (1,1) string
                options.Title (1,1) string = "Info"
                options.Icon (1,1) string = ""
            end

            messageStr = obj.getFormattedMessage(message);
            hFigure = [];

            if obj.useModernDialog("uialert")
                uialert(obj.getDialogParent(), message, options.Title, ...
                    'Icon', obj.getAlertIcon(options.Icon, "info"))
            else
                opts = obj.getDialogOptions();
                hFigure = msgbox(messageStr, options.Title, opts);
            end

            if ~nargout
                clear hFigure
            end
        end

        function answer = ask(obj, question, options)
        % ask - Open a question dialog window and return the answer

            arguments
                obj (1,1) nansen.MessageDisplay
                question (1,1) string
                options.Title (1,1) string = "Select an Option"
                options.Alternatives (1,:) string = ["Yes", "No", "Cancel"]
                options.DefaultAnswer (1,1) string = "Yes"
            end
        
            promptStr = obj.getFormattedMessage(question);
            dlgOptions = obj.getDialogOptions();

            if any( strcmp(options.Alternatives, options.DefaultAnswer) )
                defaultAnswer = char(options.DefaultAnswer);
            else
                defaultAnswer = char(options.Alternatives(1));
            end

            if obj.useModernDialog("uiconfirm")
                cancelOption = obj.getCancelOption(options.Alternatives);
                answer = uiconfirm(obj.getDialogParent(), question, options.Title, ...
                    'Options', cellstr(options.Alternatives), ...
                    'DefaultOption', defaultAnswer, ...
                    'CancelOption', cancelOption, ...
                    'Icon', 'question');
                answer = char(answer);
            else
                dlgOptions.Default = defaultAnswer;
                answer = questdlg(promptStr, options.Title, ...
                    options.Alternatives{:}, dlgOptions);
            end
        end

        function warn(obj, message, options)
        % warn - Open a message box with warning message

            arguments
                obj (1,1) nansen.MessageDisplay
                message (1,1) string
                options.Title (1,1) string = "Warning"
            end

            messageStr = obj.getFormattedMessage(message);

            if obj.useModernDialog("uialert")
                uialert(obj.getDialogParent(), message, options.Title, ...
                    'Icon', 'warning')
            else
                opts = obj.getDialogOptions();
                warndlg(messageStr, options.Title, opts)
            end
        end

        function alert(obj, message, options)
        % alert - Open a message box with error message

            arguments
                obj (1,1) nansen.MessageDisplay
                message (1,1) string
                options.Title (1,1) string = "Error"
            end
            
            messageStr = obj.getFormattedMessage(message);

            if obj.useModernDialog("uialert")
                uialert(obj.getDialogParent(), message, options.Title, ...
                    'Icon', 'error')
            else
                opts = obj.getDialogOptions();
                errordlg(messageStr, options.Title, opts)
            end
        end

        function [hDialog, dialogCleanupObj] = wait(obj, message, options)
        % wait - Open an indeterminate progress dialog.

            arguments
                obj (1,1) nansen.MessageDisplay
                message (1,1) string = "Please wait..."
                options.Title (1,1) string = "Please Wait"
                options.Value (1,1) double {mustBeGreaterThanOrEqual(options.Value, 0), mustBeLessThanOrEqual(options.Value, 1)} = 0
                options.Indeterminate (1,1) matlab.lang.OnOffSwitchState = "on"
            end

            if obj.useModernDialog("uiprogressdlg")
                hDialog = uiprogressdlg(obj.getDialogParent(), ...
                    'Title', options.Title, ...
                    'Message', message, ...
                    'Value', options.Value, ...
                    'Indeterminate', char(options.Indeterminate));
            else
                hDialog = waitbar(options.Value, message);
            end

            if nargout == 2
                dialogCleanupObj = onCleanup(@()deleteWaitbarIfValid(hDialog));
            end
        end

        function updateProgress(~, hDialog, value, message)
        % updateProgress - Update progress dialog value and optional message.

            arguments
                ~
                hDialog
                value (1,1) double {mustBeGreaterThanOrEqual(value, 0), mustBeLessThanOrEqual(value, 1)}
                message (1,1) string = string(missing)
            end

            if isempty(hDialog) || ~isvalid(hDialog)
                return
            end

            if isprop(hDialog, 'Value')
                hDialog.Value = value;
                if ~ismissing(message) && isprop(hDialog, 'Message')
                    hDialog.Message = message;
                end
            else
                if ismissing(message)
                    waitbar(value, hDialog)
                else
                    waitbar(value, hDialog, message)
                end
            end
        end
    end

    methods (Access = private)
        function opts = getDialogOptions(~)
            opts = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
        end

        function formattedMessage = getFormattedMessage(obj, message)
            if ~obj.useModernDialog("uialert") && nansen.util.isJavaFrameSupported()
                % For javaframe backed figures, the fontsize of modal
                % dialogs is small, so we increase it via text formatting.
                formatSpec = sprintf('\\fontsize{%d}', obj.FontSize);
                formattedMessage = strcat(formatSpec, message);
                
                % Fix some characters that are interpreted as tex markup
                formattedMessage = strrep(formattedMessage, '_', '\_');
            else
                formattedMessage = message;
            end
        end

        function tf = useModernDialog(obj, functionName)
            tf = obj.hasDialogFunction(functionName) && ...
                    obj.hasUiFigureParent() && ...
                    obj.hasVisibleFigureParent();
        end

        function tf = hasDialogFunction(~, functionName)
            tf = exist(functionName, 'file') == 2 || exist(functionName, 'builtin') == 5;
        end

        function tf = hasUiFigureParent(obj)
            hFigure = obj.getDialogParent();
            tf = nansen.ui.utility.isWebBasedUIFigure(hFigure);
        end

        function tf = hasVisibleFigureParent(obj)
            hFigure = obj.getDialogParent();
            tf = strcmp(hFigure.Visible, 'on');
        end

        function hFigure = getDialogParent(obj)
            hFigure = [];

            if isempty(obj.App)
                return
            elseif isa(obj.App, 'matlab.ui.Figure')
                hFigure = obj.App;
            elseif isobject(obj.App) && isprop(obj.App, 'Figure')
                try
                    hFigure = obj.App.Figure;
                catch
                    hFigure = [];
                end
            end

            if isempty(hFigure) || ~isa(hFigure, 'matlab.ui.Figure')
                hFigure = [];
            end
        end

        function icon = getAlertIcon(~, icon, defaultIcon)
            if strlength(icon) == 0
                icon = defaultIcon;
            end
            icon = char(icon);
        end

        function cancelOption = getCancelOption(~, alternatives)
            cancelIdx = find(strcmp(alternatives, "Cancel"), 1, 'first');
            if isempty(cancelIdx)
                cancelIdx = numel(alternatives);
            end
            cancelOption = char(alternatives(cancelIdx));
        end
    end
end

function deleteWaitbarIfValid(waitbarHandle)
    if ~isempty(waitbarHandle) && isvalid(waitbarHandle)
        delete(waitbarHandle)
    end
end
