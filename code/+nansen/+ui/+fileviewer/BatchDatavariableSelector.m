classdef BatchDatavariableSelector < handle

    properties
        PathName (1,1) string
        DataLocationName (1,1) string
        SessionObject (1,1)
    end

    properties (Access = private)
        Figure matlab.ui.Figure
        MainGridLayout matlab.ui.container.GridLayout
        DataTree
        FinishButton matlab.ui.control.Button
        CancelButton matlab.ui.control.Button
    end

    methods
        function app = BatchDatavariableSelector(pathName, dataLocationName, sessionObject)
            arguments
                pathName (1,1) string % MustBeFile or MustBeFolder
                dataLocationName (1,1) string
                sessionObject
            end

            app.PathName = pathName;
            app.DataLocationName = dataLocationName;
            app.SessionObject = sessionObject;
            
            app.createComponents()
            app.DataTree.loadFile(pathName)
        end

        function delete(app)
            if ~isempty(app.Figure) && isvalid(app.Figure)
                delete(app.Figure)
            end
        end
    end

    methods (Access = private) % Creation
        function createComponents(app)
            app.Figure = uifigure();
            app.Figure.Name = "Data Variable Selector";
            app.Figure.CloseRequestFcn = @(s,e) app.delete;

            app.MainGridLayout = uigridlayout(app.Figure);
            app.MainGridLayout.RowHeight = {'1x', 25};
            app.MainGridLayout.ColumnWidth = {'1x', 100, '0.25x', 100, '1x'};

            app.DataTree = datatree.ui.FileContentTree(app.MainGridLayout, ...
                "ExpandAllOnCreation", "on");
            app.DataTree.UITree.Layout.Column = [1,5];
            app.DataTree.UITree.Layout.Row = 1;

            app.FinishButton = uibutton(app.MainGridLayout);
            app.FinishButton.Layout.Column = 2;
            app.FinishButton.Layout.Row = 2;
            app.FinishButton.Text = "Select";
            app.FinishButton.ButtonPushedFcn = @(s,e) app.onFinishButtonPushed;

            app.CancelButton = uibutton(app.MainGridLayout);
            app.CancelButton.Layout.Column = 4;
            app.CancelButton.Layout.Row = 2;
            app.CancelButton.Text = "Cancel";
            app.CancelButton.ButtonPushedFcn = @(s,e) app.onCancelButtonPushed;
        end
    end

    methods (Access = private) % Update / Callbacks
        function onFinishButtonPushed(app)
            import nansen.config.varmodel.uiCreateDataVariableFromFile

            % Get selected variables from tree.
            variableNames = app.DataTree.CheckedNodeNames;

            % Run the ui create data variable...
            newDataVariable = uiCreateDataVariableFromFile(...
                char(app.PathName), app.DataLocationName, app.SessionObject, ...
                "SkipFields", "VariableName");
            
            if ~isempty(newDataVariable)
                variableModel = app.SessionObject.VariableModel;

                for i = 1:numel(variableNames)
                    % Replace name in variable structure
                    thisItem = newDataVariable;
                    thisItem.VariableName = char(variableNames(i));
                    variableModel.insertItem(thisItem)
                end
                variableModel.save()
            end
            delete(app)
        end

        function onCancelButtonPushed(app)
            delete(app)
        end
    end
end
