classdef DffExplorer < applify.mixin.AppPlugin % signalviewer plugin
    
    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false    % Ignore settings file
        DEFAULT_SETTINGS = []           % This class uses an optionsmanager
    end

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
            
            obj.editSettings()

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
            obj.MenuItem(1).PlotShifts.Callback = @obj.editSettings;
            
        end
        
        function assignDefaultOptions(obj)
            functionName = 'nansen.twophoton.roisignals.computeDff';
            obj.OptionsManager = nansen.manage.OptionsManager(functionName);
            obj.settings = obj.OptionsManager.getOptions;
        end
    end
    
    methods (Access = protected)
        
        function onSettingsChanged(obj, name, value)
            
            obj.settings_.(name) = value;
                        
            obj.RoiSignalArray.DffOptions = obj.settings;
            obj.RoiSignalArray.resetSignals('all', {'dff'})
            
            %obj.updateSignalPlot(obj.DisplayedRoiIndices, 'replace', {'dff'}, true);
            
        end
    end
end
