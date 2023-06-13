classdef computeDff < nansen.session.SessionMethod
%COMPUTEDFF Summary of this function goes here
%   Detailed explanation goes here
    
    properties (Constant) % SessionMethod attributes
        MethodName = 'Compute Delta F over F'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true;
        OptionsManager = nansen.OptionsManager(mfilename('class')) % todo...
    end

    properties (Constant)
        DATA_SUBFOLDER = 'roisignals' % defined in nansen.DataMethod
        VARIABLE_PREFIX	= ''          % defined in nansen.DataMethod
    end
    
    methods
        
        function obj = computeDff(varargin)
            
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargout % how to generalize this???
                obj.runMethod()
                clear obj
            end 
        end
        
    end
    
    methods (Static)
        function options = getDefaultOptions()
        %GETDEFAULTOPTIONS Summary of this function goes here
            options = nansen.twophoton.roisignals.getDffParameters();
        end
    end

    methods
        
        function runMethod(obj)

            import nansen.twophoton.roisignals.computeDff
            
            obj.SessionObjects.validateVariable('RoiSignals_MeanF')
            signalArray = obj.loadData('RoiSignals_MeanF');

            if ~strcmp(obj.Options.dffFcn, 'dffClassic')
                obj.SessionObjects.validateVariable('RoiSignals_NeuropilF')
                signalArray = cat(2, signalArray, obj.loadData('RoiSignals_NeuropilF'));
            end
            
            % Reshape signals to have correct dimensions and sizes for the
            % dff functions. (numsamples x numsubregions x numrois)
            if contains(signalArray.Properties.VariableNames, ...
                    'RoiSignals_NeuropilF')
                signalArray = cat(3, signalArray.RoiSignals_MeanF, ...
                    signalArray.RoiSignals_NeuropilF );
                signalArray = permute( signalArray, [1,3,2] );
            else
                signalArray = signalArray.RoiSignals_MeanF;
                signalArray = reshape(signalArray, size(signalArray, 1), 1, []);
                if ~strcmp(obj.Options.dffFcn, 'dffClassic')
                    errMsg = sprintf('Neuropil signals are required for the method "%s", but were not available.', obj.Options.dffFcn );
                    error(errMsg);
                end
            end
            
            dff = computeDff(signalArray, obj.Options);
            obj.saveData('RoiSignals_Dff', dff) 
            
        end
        
        function wasSuccess = preview(obj) 
            h = openDffExplorer(obj.SessionObjects);
            wasSuccess = obj.finishPreview(h);
        end

        function printTask(obj, varargin)
            fprintf(varargin{:})
        end
        
    end

end



function hDffPlugin = openDffExplorer(sessionObj)

    % Load rois
    roiArray = sessionObj.loadData('RoiArray');
    
    % Load signals (Todo: Should be able to do this in one line
    roiSignalTableMeanF = sessionObj.loadData('RoiSignals_MeanF');
    roiSignalTableNPilF = sessionObj.loadData('RoiSignals_NeuropilF');
    roiSignalTable = cat(2, roiSignalTableMeanF, roiSignalTableNPilF);
    
    % Create roi group
    if isa(roiArray, 'roimanager.roiGroup')
        roiGroup = roiArray;
    else
        roiGroup = roimanager.roiGroup(roiArray);
    end
    
    % Open roitable app
    hTableViewer = roimanager.RoiTable(roiGroup);
    
    % Create a roi signal array....
    rs = nansen.roisignals.RoiSignalArrayExtracted(roiSignalTable, roiGroup);

    % Open roi signalviewer app
    hSignalviewer = roisignalviewer.App(rs);
    hSignalviewer.RoiGroup = roiGroup;
    hSignalviewer.showSignal('dff')
    hSignalviewer.showLegend()
    
    % Open the dff options
    hDffPlugin = nansen.plugin.signalviewer.DffExplorer(hSignalviewer, struct.empty, 'Modal', false);
    
    % Position apps on screen
    hSignalviewer.place('bottom')
    hTableViewer.place('left')
    hTableViewer.place('bottom', hSignalviewer.Figure.OuterPosition(4) + 5)
    hDffPlugin.place('left', hTableViewer.Figure.OuterPosition(3) + 5)
    hDffPlugin.place('bottom', hSignalviewer.Figure.OuterPosition(4) + 5)
        
    % Cleanup up if plugin is deleted.
    addlistener(hDffPlugin, 'ObjectBeingDestroyed', @(s,e) delete(hSignalviewer));
    addlistener(hDffPlugin, 'ObjectBeingDestroyed', @(s,e) delete(hTableViewer));
    
    hDffPlugin.waitfor()
    
end

