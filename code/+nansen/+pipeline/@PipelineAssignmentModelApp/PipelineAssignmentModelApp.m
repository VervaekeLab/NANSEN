classdef PipelineAssignmentModelApp < nansen.config.abstract.ConfigurationApp
    
    
    properties (Constant)
        AppName = 'Configure Pipeline Assignment'
        ModelName = 'Pipeline Model'
    end
    
    properties
        Model
        ModelBackup
    end

    methods % Constructor
        
        function obj = PipelineAssignmentModelApp(varargin)
            
            if isempty(varargin)
                                
                obj.createFigure()
                obj.Figure.Visible = 'on';
                               
                figure(obj.Figure)

                obj.createControlPanels()
                obj.createLoadingPanel()
                
                obj.setLayout()
                obj.applyTheme()

                obj.createUIModules()
                
                if ~nargout
                    clear obj
                end
            end
        end
        
    end
    
    methods (Access = protected)
        
        function onFigureClosed(obj, src, evt)
            
            % Check if changes were made to the model.
            
            newModel = obj.UIModule{1}.getUpdatedTableData();
            isDirty = ~isequal(newModel, obj.ModelBackup);
            
            if isDirty
            
                message = sprintf('Save changes to %s?', obj.ModelName);
                title = 'Confirm Save';

                selection = uiconfirm(src, message, title, 'Options', ...
                    {'Yes', 'No', 'Cancel'}, 'DefaultOption', 1, ...
                    'CancelOption', 3);

                switch selection

                    case 'Yes'
                        obj.Model.setModelData(newModel)
                        obj.Model.save()
                    case 'No'
                        obj.Model.setModelData(obj.ModelBackup)
                        obj.Model.save()
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
            uim.utility.layout.centerObjectInRectangle(obj.LoadingImage, obj.LoadingPanel)
        end

        function createControlPanels(obj)
            obj.ControlPanels = obj.createControlPanel( obj.Figure );
        end 
        
        function createUIModules(obj)
            
            obj.LoadingPanel.Visible = 'on';
            
            % Todo: Accept these as inputs on construction...
            pipelineModel = nansen.pipeline.PipelineCatalog;
        
            obj.Model = pipelineModel;
            obj.ModelBackup = pipelineModel.Data;
            
            metatableCatalog = nansen.getCurrentProject().MetaTableCatalog;
            metaTable = metatableCatalog.getMasterTable('session');
            
            args = {'PipelineModel', pipelineModel, 'Data', pipelineModel.Data(1).SessionProperties, ...
                'MetaTable', metaTable};
            
            obj.UIModule{1} = nansen.pipeline.PipelineAssignmentModelUI(obj.ControlPanels(1), args{:});
            obj.UIModule{1}.createToolbar(obj.ControlPanels(1))

            obj.LoadingPanel.Visible = 'off';
        end
        
    end
    
end