classdef extractSignalsMultiChannel < nansen.session.SessionMethod
%Extract ROI signals from all channels in a multi-channel recording.
%
%Use this when:
%- `TwoPhotonSeries_Corrected` has multiple channels.
%- The default `RoiArray` should be matched to the stack's channel and plane
%  layout before signal extraction.
%
%What happens:
%- NANSEN loads the corrected stack and temporarily selects all channels.
%- The ROI group is checked and adapted to match the stack dimensions.
%- The `SignalExtractor` processor extracts ROI and neuropil signals using
%  the configured extraction options.
%
%Outputs:
%- `RoiSignals_MeanF`: mean ROI fluorescence traces.
%- `RoiSignals_NeuropilF`: neuropil fluorescence traces.
%- `OptionsSignalExtraction`: options used by the signal extractor.

    properties (Constant) % SessionMethod attributes
        MethodName = 'Extract Signals (MultiChannel)'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.processing.SignalExtractor')
    end

    properties (Constant)
        DATA_SUBFOLDER = 'roisignals'       % defined in nansen.processing.DataMethod
        VARIABLE_PREFIX	= 'RoiSignals'      % defined in nansen.processing.DataMethod
    end

    properties
        RequiredVariables = {'TwoPhotonSeries_Corrected', 'RoiArray'}
    end

    methods (Static)
        function S = getDefaultOptions()
            S = nansen.twophoton.roisignals.extract.getDefaultParameters();
        end
    end

    methods

        function obj = extractSignalsMultiChannel(varargin)

            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
    end

    methods

        function runMethod(obj)
            import roimanager.utilities.ensureRoiGroupMatchImageStack

            sessionData = nansen.session.SessionData(obj.SessionObjects);
            sessionData.updateDataVariables()

            imageStack = sessionData.TwoPhotonSeries_Corrected;
            currentChannels = imageStack.CurrentChannel;
            imageStack.CurrentChannel = 1:imageStack.NumChannels;

            roiGroup = sessionData.RoiArray;

            roiGroup = ensureRoiGroupMatchImageStack(roiGroup, imageStack);

            nansen.processing.SignalExtractor(imageStack, obj.Options, roiGroup, obj.SessionObjects)

            % Reset channels
            imageStack.CurrentChannel = currentChannels;
        end
    end

    methods
        function printTask(obj, varargin)
            fprintf(varargin{:})
        end
    end
end
