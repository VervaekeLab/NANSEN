classdef DffExplorer < applify.mixin.AppPlugin & applify.mixin.HasOptionsManager % signalviewer plugin
%DffExplorer Explore dF/F calculation options in signalviewer.
%
%   DffExplorer is a signalviewer plugin for editing dF/F options and
%   applying them to ROI fluorescence signals.
%
%   SYNTAX:
%       dffExplorerPlugin = nansen.plugin.signalviewer.DffExplorer(signalViewerHandle)
%       dffExplorerPlugin = nansen.plugin.signalviewer.DffExplorer(signalViewerHandle, options)
%       dffExplorerPlugin = nansen.plugin.signalviewer.DffExplorer(signalViewerHandle, options, Name, Value, ...)

    properties (Constant) % Implementation of AppPlugin property
        Name = 'DFF Explorer'
    end

    properties (Access = protected)
        RoiSignalArray
    end

    methods % Constructor
        function obj = DffExplorer(signalViewerHandle, varargin)
        %DffExplorer Create a dF/F options plugin for signalviewer.
        %
        %   dffExplorerPlugin = DffExplorer(signalViewerHandle) creates the
        %   plugin using default dF/F options.
        %
        %   dffExplorerPlugin = DffExplorer(signalViewerHandle, options, Name, Value, ...)
        %   creates the plugin using a struct or nansen.manage.OptionsManager
        %   for options. Remaining arguments are plugin flags or property-value
        %   pairs, such as '-p' for partial construction.

            arguments
                signalViewerHandle applify.AppWithPlugin
            end
            arguments (Repeating)
                varargin
            end

            [options, pluginArgs] = ...
                applify.mixin.HasOptionsManager.splitOptionsArgument(varargin);

            obj@applify.mixin.HasOptionsManager(options)
            obj@applify.mixin.AppPlugin(signalViewerHandle, pluginArgs{:})

            obj.setFigureTitle()
            obj.RoiSignalArray = obj.PrimaryApp.RoiSignalArray;

            obj.editOptions()
        end

        function delete(obj)
        end
    end

    methods (Access = protected) % Plugin derived methods

        function createSubMenu(obj) %#ok<MANU> % Placeholder, not implemented
        %createSubMenu Create sub menu items for the plugin

            % parentMenu = obj.findAppContextMenu();
            %
            % % Todo: Open? Close? Toggle?
            % obj.MenuItem(1).ExploreDff = uimenu(parentMenu, 'Text', 'Explore DFF', 'Enable', 'off');
            % obj.MenuItem(1).ExploreDff.Callback = @obj.editOptions;
        end

        function assignDefaultOptions(obj)
            functionName = 'nansen.twophoton.roisignals.computeDff';
            obj.OptionsManager = nansen.manage.OptionsManager(functionName);
        end
    end

    methods (Access = protected)

        function onOptionsChanged(obj, name, value)
            if nargin == 3
                options = obj.Options;
                options.(name) = value;
                obj.Options = options;
            end

            obj.RoiSignalArray.DffOptions = obj.Options;
            obj.RoiSignalArray.resetSignals('all', {'dff'})
        end
    end
end
