classdef ModuleManagerApp < nansen.config.abstract.ConfigurationApp
%ModuleManagerApp Create an app for the module manager

    properties (Constant)
        AppName = 'Module Manager'
    end

    properties (Access = private)
        UIControlPanel
    end

    events
        ModuleSelectionChanged
    end

    methods
        function obj = ModuleManagerApp(selectedModules)

            obj.FigureSize = [699+40, 349];

            obj.createFigure()
            obj.AllowResize = 'on';
            obj.Figure.Visible = 'on';
            
            obj.UIControlPanel = obj.createControlPanel(obj.Figure);
            obj.UIControlPanel.BorderType = "None";
            obj.UIControlPanel.BackgroundColor = "white";

            obj.updateControlPanelPosition()
            obj.createLoadingPanel()

            %obj.setLayout()
            obj.applyTheme()

            obj.UIModule{1} = nansen.config.module.ModuleManagerUI(obj.UIControlPanel);
            addlistener(obj.UIModule{1}, 'ModuleSelectionChanged', @obj.onSelectionChanged);
            
            if nargin >= 1
                obj.UIModule{1}.setSelectedModules(selectedModules)
            end

            if ~nargout; clear obj; end
        end
    end

    methods (Access = public)
        function setSelectedModules(obj, dataModules)
            obj.UIModule{1}.setSelectedModules(dataModules)
        end
    end

    methods (Access = protected)
        function resizeChildren(obj)
            obj.updateControlPanelPosition()
        end
    end

    methods (Access = private)
        function onSelectionChanged(obj, ~, evtData)
            obj.notify('ModuleSelectionChanged', evtData)
        end

        function updateControlPanelPosition(obj)
            panelSize = obj.Figure.Position(3:4) - [0, 40];
            obj.UIControlPanel.Position = [0, 0, panelSize];
            drawnow
        end
    end
end
