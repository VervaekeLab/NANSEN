classdef MessageDisplay < handle
% MessageDisplay - Class interface for displaying messages to user.

    properties (SetAccess = private) % Or immutable?
        App % Placeholder for now
    end

    properties % Preferences
        FontSize = 14
    end

    methods
        function hFigure = inform(obj, message, options)
        % inform - Open a message box with info message
            
            arguments
                obj (1,1) nansen.MessageDisplay
                message (1,1) string
                options.Title (1,1) string = "Info"
                options.Icon (1,1) string = ""
            end

            messageStr = obj.getFormattedMessage(message);
            opts = obj.getDialogOptions();
            
            hFigure = msgbox(messageStr, options.Title, opts);
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
                defaultAnswer = options.Alternatives{1};
            end
            dlgOptions.Default = defaultAnswer;
            answer = questdlg(promptStr, options.Title, ...
                options.Alternatives{:}, dlgOptions);
        end

        function warn(obj, message, options)
        % warn - Open a message box with warning message

            arguments
                obj (1,1) nansen.MessageDisplay
                message (1,1) string
                options.Title (1,1) string = "Warning"
            end

            messageStr = obj.getFormattedMessage(message);
            opts = obj.getDialogOptions();
            
            warndlg(messageStr, options.Title, opts)
        end

        function alert(obj, message, options)
        % alert - Open a message box with error message

            arguments
                obj (1,1) nansen.MessageDisplay
                message (1,1) string
                options.Title (1,1) string = "Error"
            end
            
            messageStr = obj.getFormattedMessage(message);
            opts = obj.getDialogOptions();
            
            errordlg(messageStr, options.Title, opts)
        end

        function wait(obj) %#ok<MANU>
            % Not implemented yet
        end
    end

    methods (Access = private)
        function opts = getDialogOptions(~)
            opts = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
        end

        function formattedMessage = getFormattedMessage(obj, message)
            % Prepend specifier with fontsize
            formatSpec = sprintf('\\fontsize{%d}', obj.FontSize);
            formattedMessage = strcat(formatSpec, message);
            
            % Fix some characters that are interpreted as tex markup
            formattedMessage = strrep(formattedMessage, '_', '\_');
        end
    end
end