classdef Caiman < nansen.session.SessionMethod
%DeconvolutionCaImAn Summary of this function goes here
%   Detailed explanation goes here
    
    properties (Constant) % SessionMethod attributes
        MethodName = 'Deconvolution CaImAn'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true;
        OptionsManager = nansen.OptionsManager(mfilename('class')) % todo...
    end
    
    methods (Static)
        function options = getDefaultOptions()
        %GETDEFAULTOPTIONS Summary of this function goes here
            options = nansen.twophoton.roisignals.getDeconvolutionParameters();
        end
    end
    
    methods
        
        function obj = Caiman(varargin)
            
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargout % how to generalize this???
                obj.runMethod()
                clear obj
            end 
        end
        
    end
    
    methods
        
        function runMethod(obj)

            import nansen.twophoton.roisignals.deconvolveDff
            
            obj.SessionObjects.validateVariable('RoiSignals_Dff')
            signalArray = obj.loadData('RoiSignals_Dff');
            
            dff = signalArray.RoiSignals_Dff;
            [deconvolved, denoised] = deconvolveDff(dff, obj.Parameters);
            
            obj.SessionObjects.saveData('RoiSignals_Deconvolved', deconvolved)
            obj.SessionObjects.saveData('RoiSignals_Denoised', denoised)
            
            % Todo: get computed timeconstants and other params and save
            
            obj.saveData('OptionsDeconvolution', obj.Parameters, ...
                'Subfolder', 'roisignals', 'IsInternal', true)
            
        end
        
        function wasSuccess = preview(obj) 
            h = openDeconvolutionExplorer(obj.SessionObjects);
            wasSuccess = obj.finishPreview(h);
        end
        
    end

end

function hDffPlugin = openDeconvolutionExplorer(sessionObj)

    % Todo: Get samplerate from metadata and inject to parameters....

    % Make sure dff is present.
    sessionObj.validateVariable('RoiSignals_Dff')

    % Load rois
    roiArray = sessionObj.loadData('RoiArray');
    
    % Load signals
    roiSignalTable = sessionObj.loadData('RoiSignals_MeanF');
    
    
    % Create roi group
    roiGroup = roimanager.roiGroup(roiArray);

    % Open roitable app
    hTableViewer = roimanager.RoiTable(roiGroup);
    hTableViewer.SelectionMode = 'single';
    
    % Create a roi signal array....
    rs = nansen.roisignals.RoiSignalArrayExtracted(roiSignalTable, roiGroup);

    % Open roi signalviewer app
    hSignalviewer = roisignalviewer.App(rs);
    hSignalviewer.RoiGroup = roiGroup;
    hSignalviewer.showSignal('dff')
    hSignalviewer.showSignal('deconvolved')
    
    hSignalviewer.showLegend()
    
    % Open the dff options
    hDffPlugin = nansen.plugin.signalviewer.CaimanDeconvolution(hSignalviewer, [], 'Modal', false);
    
    % Position apps on screen
    hSignalviewer.place('bottom')
    hTableViewer.place('left')
    hTableViewer.place('bottom', hSignalviewer.Figure.OuterPosition(4))
    hDffPlugin.place('left', hTableViewer.Figure.OuterPosition(3))
    hDffPlugin.place('bottom', hSignalviewer.Figure.OuterPosition(4))
        
    % Cleanup up if plugin is deleted.
    addlistener(hDffPlugin, 'ObjectBeingDestroyed', @(s,e) delete(hSignalviewer));
    addlistener(hDffPlugin, 'ObjectBeingDestroyed', @(s,e) delete(hTableViewer));
    
    hDffPlugin.waitfor()
    
end