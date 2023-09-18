classdef ModuleManagerApp < nansen.config.abstract.ConfigurationApp
%ModuleManagerApp Create an app for the module manager
%
%   Todo: Program this using traditional gui figure for backwards
%   compatibility and more responsive figure.


    properties (Constant)
        AppName = 'Module Manager'
    end

    events 
        ModuleSelectionChanged
    end

    methods
        function obj = ModuleManagerApp(selectedModules)

            obj.FigureSize = [699+40, 349];

            obj.createFigure()
            obj.Figure.Visible = 'on';

            cPanel = obj.createControlPanel(obj.Figure);
            obj.createLoadingPanel()

            %obj.setLayout()
            panelSize = obj.Figure.Position(3:4) - [40, 60];
            cPanel.Position = [20, 20, panelSize];
            
            obj.applyTheme()

            obj.UIModule{1} = nansen.config.module.ModuleManagerUI(cPanel); 
            addlistener(obj.UIModule{1}, 'ModuleSelectionChanged', @obj.onSelectionChanged);
            
            if nargin >= 1
                obj.UIModule{1}.setSelectedModules(selectedModules)
            end

            if ~nargout; clear obj; end
            
            %obj@applify.ModularApp
            % Create tabs
            %obj.isConstructed = true;
        end
    end

    methods (Access = public)
        function setSelectedModules(obj, dataModules)
            obj.UIModule{1}.setSelectedModules(dataModules)
        end
    end

    methods (Access = private)
        function onSelectionChanged(obj, ~, evtData)
            obj.notify('ModuleSelectionChanged', evtData)
        end
    end

end
