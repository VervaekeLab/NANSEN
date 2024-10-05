classdef CaimanDeconvolution < applify.mixin.AppPlugin % signalviewer plugin
    
    properties (Constant, Hidden = true)
        USE_DEFAULT_SETTINGS = false    % Ignore settings file
        DEFAULT_SETTINGS = []           % This class uses an optionsmanager
    end

    properties (Constant) % Implementation of AppPlugin property
        Name = 'CaImAn Deconvolution'
    end
    
    properties
        PrimaryAppName = 'Roi Signal Explorer'
    end
    
    properties (Access = protected)
        RoiSignalArray
    end
    
    properties (Access = private)
        Mode
        hLineDeconvolved
        hLineDenoised
    end
    
    methods % Constructor
        function obj = CaimanDeconvolution(varargin)
            %obj@imviewer.ImviewerPlugin(varargin{:})
            
            obj@applify.mixin.AppPlugin(varargin{:})
            obj.PrimaryApp = varargin{1};
            obj.PrimaryApp.Figure.Name = obj.Name;
            obj.RoiSignalArray = obj.PrimaryApp.RoiSignalArray;
            
            obj.Mode = 'UpdateAll';
                        
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
            obj.MenuItem(1).ExploreDff = uimenu(m, 'Text', 'Deconvolve...', 'Enable', 'off');
            obj.MenuItem(1).PlotShifts.Callback = @obj.editSettings;
            
        end
        
        function assignDefaultOptions(obj)
            functionName = 'ophys.twophoton.process.deconvolution.Caiman';
            obj.OptionsManager = nansen.manage.OptionsManager(functionName);
            obj.settings = obj.OptionsManager.getOptions;
        end
    end
    
    methods (Access = protected)
        
        function onSettingsChanged(obj, name, value)
            
            obj.settings_.(name) = value;
            obj.RoiSignalArray.DeconvolutionOptions = obj.settings;
            
            obj.PrimaryApp.displayMessage('Updating Deconvolved Signal...')
            
            switch obj.Mode
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
            
            [dec, den, ~] = deconvolveDff(dff_, obj.settings);%, options)
            
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
