classdef DffExplorer < applify.mixin.AppPlugin & applify.mixin.HasOptionsManager % signalviewer plugin

    properties (Constant) % Implementation of AppPlugin property
        Name = 'DFF Explorer'
    end
    
    properties
        PrimaryAppName = 'Roi Signal Explorer'
    end
    
    properties (Access = protected)
        RoiSignalArray
    end
    
    methods % Constructor
        function obj = DffExplorer(varargin)
            %obj@imviewer.ImviewerPlugin(varargin{:})
            
            obj@applify.mixin.AppPlugin(varargin{:})
            obj.PrimaryApp = varargin{1};
            obj.PrimaryApp.Figure.Name = 'DFF Explorer';
            obj.RoiSignalArray = obj.PrimaryApp.RoiSignalArray;
            
            obj.editOptions()

        end
        
        function delete(obj)
            
        end
    end
    
    methods (Access = protected) % Plugin derived methods
                
        function createSubMenu(obj)
        %createSubMenu Create sub menu items for the normcorre plugin
        
            %m = obj.PrimaryApp.hContextMenu;
            %m = findobj(obj.PrimaryApp.Figure, 'Tag', 'App Context Menu');
            return
            
            % Todo: Check if menu is already added...
            
            % Todo: Open? Close? Toggle?
            obj.MenuItem(1).ExploreDff = uimenu(m, 'Text', 'Explore DFF', 'Enable', 'off');
            obj.MenuItem(1).PlotShifts.Callback = @obj.editOptions;
            
        end
        
        function assignDefaultOptions(obj)
            functionName = 'nansen.twophoton.roisignals.computeDff';
            obj.OptionsManager = nansen.manage.OptionsManager(functionName);
        end
    end

    methods (Access = protected)

        function onOptionsChanged(obj)
            obj.RoiSignalArray.DffOptions = obj.Options;
            obj.RoiSignalArray.resetSignals('all', {'dff'})
        end
    end
end
