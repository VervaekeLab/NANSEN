classdef VariableModelApp < nansen.config.abstract.ConfigurationApp
    
    
    properties (Constant)
        AppName = 'Configure Variable Model'
    end
    
    
    properties
        VariableModel
        ModelBackup
    end

    methods % Constructor
        
        function obj = VariableModelApp(varargin)
            
            if isempty(varargin)
                                
                obj.createFigure()
                obj.Figure.Visible = 'on';
                
                obj.createControlPanels()
                obj.createLoadingPanel()
                
                obj.setLayout()
                obj.applyTheme()

                obj.createUIModules(1)
                
            end
            
            
        end
        
    end
    
    methods (Access = protected)
        
        function onFigureClosed(obj, src, evt)
            
            if isempty(obj.UIModule)
                delete(obj.Figure); return
            end
            
            % Check if changes were made to the model.
            newModel = obj.UIModule{1}.getUpdatedTableData();
            isDirty = ~isequal(newModel, obj.ModelBackup);
            
            if isDirty
            
                message = 'Save changes to Variable Model?';
                title = 'Confirm Save';

                selection = uiconfirm(src, message, title, 'Options', ...
                    {'Yes', 'No', 'Cancel'}, 'DefaultOption', 1, ...
                    'CancelOption', 3);

                switch selection

                    case 'Yes'
                        obj.VariableModel.setVariableList(newModel)
                        obj.VariableModel.save()
                    case 'No'
                        obj.VariableModel.setVariableList(obj.ModelBackup)
                        obj.VariableModel.save()
                    otherwise
                        return

                end
                
            end

            delete(obj.Figure)
            
        end
        
    end
    
    methods (Access = private)
        
        function setLayout(obj)
            % Make sure inner position is : [699,229]
            
            % Todo: Make this part of abstract method... Adjust size if a
            % tabgroup is added....
            
            targetPosition = [699, 229] + [0,20] + [40, 40];
            
            pos = obj.Figure.Position;
            
            deltaSize = targetPosition - pos(3:4);
            
            % Resize components
            obj.Figure.Position(3:4) = obj.Figure.Position(3:4) + deltaSize;
            obj.LoadingPanel.Position(3:4) = obj.Figure.Position(3:4);
            obj.updateLoadPanelComponentPositions()

        end

        function createControlPanels(obj)
            obj.ControlPanels = obj.createControlPanel( obj.Figure );
        end 
        
        function createUIModules(obj, ~)
            
            obj.LoadingPanel.Visible = 'on';
            
            % Todo: Accept these as inputs on construction...
            variableModel = nansen.config.varmodel.VariableModel;
            datalocationModel = nansen.config.dloc.DataLocationModel;
        
            obj.VariableModel = variableModel;
            obj.ModelBackup = variableModel.Data;
            
            % Todo: If items are more the 10-15, create an
            % uiw.widget.Table...
            
            args = {'DataLocationModel', datalocationModel, ...
                'VariableModel', variableModel, 'Data', variableModel.Data};
            
            obj.UIModule{1} = nansen.config.varmodel.VariableModelUI(obj.ControlPanels(1), args{:});

            obj.LoadingPanel.Visible = 'off';

        end
        
    end
    
end