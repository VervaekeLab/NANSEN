classdef VariableModelApp < nansen.config.abstract.ConfigurationApp
    
    properties (Constant)
        AppName = 'Configure Variable Model'
    end
    
    properties
        DataLocationModel
        VariableModel
        ModelBackup % Backup of data from variable model
    end

    events
        VariableModelChanged
    end

    methods % Constructor
        
        function obj = VariableModelApp(varargin)
            
            [nvPairs, varargin] = utility.getnvpairs(varargin{:});
            obj.assignPVPairs(nvPairs{:})

            if isempty(obj.VariableModel)
                obj.VariableModel = nansen.VariableModel();
            end

            if isempty(obj.DataLocationModel)
                obj.DataLocationModel = nansen.DataLocationModel();
            end
            
            % Todo: Should be part of VariableModel?
            obj.ModelBackup = obj.VariableModel.Data;

            if isempty(varargin)
                
                obj.FigureSize = [699, 449];
                
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

    methods % Public
        
        function doCancel = promptSaveChanges(obj)
        %promptSaveChanges Prompt user if UI changes should be saved.
        
            % Initialize output (assume user is not going to abort)
            doCancel = false;   
            
            % Check if changes were made to the model.
            newModel = obj.UIModule{1}.getUpdatedTableData();
            isDirty = ~isequal(newModel, obj.ModelBackup);
            
            if isDirty
            
                message = 'Save changes to Variables?';
                title = 'Confirm Save';

                selection = uiconfirm(obj.Figure, message, title, 'Options', ...
                    {'Yes', 'No', 'Cancel'}, 'DefaultOption', 1, ...
                    'CancelOption', 3);

                switch selection

                    case 'Yes'
                        obj.VariableModel.setVariableList(newModel)
                        obj.VariableModel.save()
                        obj.ModelBackup = obj.VariableModel.Data;
                        obj.notify('VariableModelChanged', event.EventData)
                    case 'No'
                        obj.VariableModel.setVariableList(obj.ModelBackup)
                        obj.VariableModel.save()
                        obj.ModelBackup = obj.VariableModel.Data;
                    otherwise
                        doCancel = true; % User decided to cancel.
                        return
                end
            end
        end

    end
    
    methods (Access = protected)
        
        function onFigureClosed(obj, src, evt)
            
            if isempty(obj.UIModule)
                delete(obj.Figure); return
            end

            wasCanceled = obj.promptSaveChanges();
            
            if wasCanceled
                return
            else
                delete(obj.Figure)
            end
       end
        
        % Override superclass (ConfigurationApp) method
        function hideApp(obj)
        %hideApp Make app invisible. Similar to closing app, but app
        %remains in memory.

            wasCanceled = obj.promptSaveChanges();
            
            if wasCanceled
                return
            else
                hideApp@nansen.config.abstract.ConfigurationApp(obj)
            end
        end

        function setLayout(obj)
            % Make sure inner position is : [699,229]
            
            % Todo: Make this part of abstract method... Adjust size if a
            % tabgroup is added....
            
            margins = [20, 20, 20, 20];
            
            targetPosition = obj.FigureSize + [0,20] + [40, 40];
            
            pos = obj.Figure.Position;
            
            deltaSize = targetPosition - pos(3:4);
            
            % Resize components
            obj.Figure.Position(3:4) = obj.Figure.Position(3:4) + deltaSize;
            obj.LoadingPanel.Position(3:4) = obj.Figure.Position(3:4);
            obj.updateLoadPanelComponentPositions()
            
            panelSize = obj.Figure.Position(3:4) - [40, 60];
            obj.ControlPanels.Position = [20, 20, panelSize];
        end
        
    end

    methods (Access = private)

        function createControlPanels(obj)
            obj.ControlPanels = obj.createControlPanel( obj.Figure );
        end 
        
        function createUIModules(obj, ~)
            
            obj.LoadingPanel.Visible = 'on';
            
            % Todo: If items are more the 10-15, create an
            % uiw.widget.Table...
            
            args = {'DataLocationModel', obj.DataLocationModel, ...
                'VariableModel', obj.VariableModel, ...
                'Data', obj.VariableModel.Data};
            
            obj.UIModule{1} = nansen.config.varmodel.VariableModelUI(...
                obj.ControlPanels(1), args{:});

            obj.LoadingPanel.Visible = 'off';
        end

    end
    
end