classdef CaimanDeconvolution < applify.mixin.AppPlugin & applify.mixin.HasOptionsManager % signalviewer plugin
%CaimanDeconvolution Explore CaImAn deconvolution options in signalviewer.
%
%   CaimanDeconvolution is a signalviewer plugin for editing deconvolution
%   options and applying them to ROI dF/F signals.
%
%   SYNTAX:
%       deconvolutionPlugin = nansen.plugin.signalviewer.CaimanDeconvolution(signalViewerHandle)
%       deconvolutionPlugin = nansen.plugin.signalviewer.CaimanDeconvolution(signalViewerHandle, options)
%       deconvolutionPlugin = nansen.plugin.signalviewer.CaimanDeconvolution(signalViewerHandle, options, Name, Value, ...)

    properties (Constant) % Implementation of AppPlugin property
        Name = 'CaImAn Deconvolution'
    end
    
    properties (Access = protected)
        RoiSignalArray
    end
    
    properties (Access = private)
        PlotUpdateMode (1,1) string {mustBeMember(PlotUpdateMode, ...
            ["UpdateAll", "UpdateVisiblePlotOnly"])} = "UpdateAll"
        hLineDeconvolved
        hLineDenoised
    end
    
    methods % Constructor
        function obj = CaimanDeconvolution(signalViewerHandle, varargin)
        %CaimanDeconvolution Create a deconvolution plugin for signalviewer.
        %
        %   deconvolutionPlugin = CaimanDeconvolution(signalViewerHandle)
        %   creates the plugin using default CaImAn deconvolution options.
        %
        %   deconvolutionPlugin = CaimanDeconvolution(signalViewerHandle, options, Name, Value, ...)
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
            if ~isempty(obj.hLineDeconvolved) && isvalid(obj.hLineDeconvolved)
                delete(obj.hLineDeconvolved)
            end
            if ~isempty(obj.hLineDenoised) && isvalid(obj.hLineDenoised)
                delete(obj.hLineDenoised)
            end
        end
    end
    
    methods (Access = protected) % Plugin derived methods
                
        function createSubMenu(obj) %#ok<MANU> % Placeholder, not implemented
        %createSubMenu Create sub menu items for the plugin
            % parentMenu = obj.findAppContextMenu();
            %
            % % Todo: Open? Close? Toggle?
            % obj.MenuItem(1).Deconvolve = uimenu(parentMenu, 'Text', 'Deconvolve...', 'Enable', 'off');
            % obj.MenuItem(1).Deconvolve.Callback = @obj.editOptions;
        end
        
        function assignDefaultOptions(obj)
            functionName = 'nansen.twophoton.roisignals.deconvolveDff';
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

            obj.RoiSignalArray.DeconvolutionOptions = obj.Options;
            
            obj.PrimaryApp.displayMessage('Updating Deconvolved Signal...')
            
            switch obj.PlotUpdateMode
                case 'UpdateVisiblePlotOnly'
                    obj.updateInternal()
                    
                case 'UpdateAll'
                    obj.RoiSignalArray.resetSignals('all', {'deconvolved', 'denoised'})
            end
            
            obj.PrimaryApp.clearMessage()
        end
        
        function updateInternal(obj)
            
            import nansen.twophoton.roisignals.deconvolveDff
                               
            % Get visible dff...
            roiInd = obj.PrimaryApp.DisplayedRoiIndices;
            dff = obj.RoiSignalArray.getSignals(roiInd, 'dff');
            
            hAx = obj.PrimaryApp.Axes;
            xLim = hAx.XLim;
            xData = 1:numel(dff);
                        
            isVisible = xData > xLim(1) & xData < xLim(2);
            dff_ = dff(isVisible);
            xData_ = xData(isVisible);
            
            [dec, den, ~] = deconvolveDff(dff_, obj.Options);
            
            if isempty(obj.hLineDeconvolved)
                yyaxis(hAx, 'right')
                obj.hLineDeconvolved = plot(hAx, xData_, dec);
                obj.hLineDenoised = plot(hAx, xData_, den);
                
                h = [obj.hLineDeconvolved, obj.hLineDenoised];
                set(h, 'HitTest', 'off', 'PickableParts', 'none')
                
            else
                set(obj.hLineDeconvolved, 'XData', xData_, 'YData', dec)
                set(obj.hLineDenoised, 'XData', xData_, 'YData', den)
            end
        end
    end
end
