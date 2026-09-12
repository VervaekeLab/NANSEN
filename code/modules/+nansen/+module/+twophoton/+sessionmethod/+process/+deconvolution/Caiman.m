classdef Caiman < nansen.session.SessionMethod
%Deconvolve delta-F-over-F traces with the CaImAn signal model.
%
%Use this when:
%- You have already computed `RoiSignals_Dff`.
%- You want denoised and event-like deconvolved traces for downstream
%  analysis or inspection.
%
%What happens:
%- NANSEN loads `RoiSignals_Dff`.
%- The selected CaImAn deconvolution parameters are applied to each ROI
%  trace.
%- Preview mode opens the deconvolution explorer so parameters can be tuned
%  before committing the run.
%
%Outputs:
%- `RoiSignals_Deconvolved`: deconvolved ROI activity estimates.
%- `RoiSignals_Denoised`: denoised delta-F-over-F traces.
%- `OptionsDeconvolution`: the options used for this run.

    properties (Constant) % SessionMethod attributes
        MethodName = 'Deconvolution CaImAn'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true;
        OptionsManager = nansen.OptionsManager(mfilename('class')) % todo...
    end

    properties (Constant)
        DATA_SUBFOLDER = 'roisignals' % defined in nansen.processing.DataMethod
        VARIABLE_PREFIX	= ''          % defined in nansen.processing.DataMethod
    end

    methods (Static)
        function options = getDefaultOptions()
        %GETDEFAULTOPTIONS Return default CaImAn deconvolution options.
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
            [deconvolved, denoised] = deconvolveDff(dff, obj.Options);

            obj.SessionObjects.saveData('RoiSignals_Deconvolved', deconvolved)
            obj.SessionObjects.saveData('RoiSignals_Denoised', denoised)

            filePath = obj.getDataFilePath('RoiSignals_Deconvolved');
            fprintf('Saved deconvolved signals to %s\n', filePath)

            % Todo: get computed timeconstants and other params and save

            obj.saveData('OptionsDeconvolution', obj.Options, ...
                'Subfolder', 'roisignals', 'IsInternal', true)
        end

        function wasSuccess = preview(obj)
            h = openDeconvolutionExplorer(obj.SessionObjects);
            wasSuccess = obj.finishPreview(h);
        end

        function printTask(obj, varargin)
            fprintf(varargin{:})
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
    roiSignalTableMeanF = sessionObj.loadData('RoiSignals_MeanF');
    roiSignalTableDff = sessionObj.loadData('RoiSignals_Dff');
    roiSignalTable = cat(2, roiSignalTableMeanF, roiSignalTableDff);

    % Create roi group
    if isa(roiArray, 'RoI')
        roiGroup = roimanager.roiGroup(roiArray);
    elseif isa(roiArray, 'roimanager.roiGroup')
        roiGroup = roiArray;
    else
        error('Invalid rois')
    end

    % Create composite roigroup for multichannel/multiplane rois
    if numel(roiGroup) > 1
        roiGroup = roimanager.CompositeRoiGroup(roiGroup);
    end

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
    hDffPlugin = nansen.plugin.signalviewer.CaimanDeconvolution(hSignalviewer, struct.empty, 'Modal', false);

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
