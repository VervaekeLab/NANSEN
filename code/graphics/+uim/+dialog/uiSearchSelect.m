classdef uiSearchSelect < handle

    properties
        Options
    end

    properties (Dependent)
        Selection
    end

    properties (Access = private)
        Figure
        Parent
        OkButton
        AutoCompleteWidget
    end

    methods
        function obj = uiSearchSelect(options, title)
            
            obj.Options = options;

            obj.Figure = figure('MenuBar','none');
            obj.Figure.Position(3:4) =  [560, 80];
            obj.Figure.Resize = 'off';
            obj.Figure.NumberTitle = 'off';
            obj.Figure.Name = title;
            obj.createComponents()
        end

        function delete(obj)
            delete(obj.Figure)
        end
    end

    methods
        function selection = get.Selection(obj)
            selection = obj.AutoCompleteWidget.Value;
        end
    end

    methods

        function uiwait(obj)
            uiwait(obj.Figure)
        end
    end

    methods (Access = private)
        function createComponents(obj)
            
            figSize = getpixelposition(obj.Figure);

            obj.Parent = obj.Figure;
            obj.AutoCompleteWidget = uics.searchAutoCompleteInputDlg(obj.Parent, obj.Options);
            obj.AutoCompleteWidget.PromptText = 'Search for a dataset';
           
            obj.AutoCompleteWidget.Position(2) = 50;
            obj.AutoCompleteWidget.Position(3) = figSize(3)-20;
            
            % Create buttons
            buttonProps = {'Style', uim.style.buttonLightMode, ...
                'HorizontalTextAlignment', 'center'};
            
            obj.OkButton = uim.control.Button_(obj.Parent, 'Text', 'Ok', buttonProps{:});
            obj.OkButton.Position = [15,10, figSize(3)-30, 22];
            obj.OkButton.CornerRadius = 7;
            obj.OkButton.Callback = @obj.onOkButtonClicked;
        end

        function onOkButtonClicked(obj, src, evt)
             uiresume(obj.Figure)
        end
    end
end
