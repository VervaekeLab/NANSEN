classdef extractSignals < nansen.session.SessionMethod
%Extract fluorescence and neuropil signals from the corrected stack.
%
%Use this when:
%- `TwoPhotonSeries_Corrected` and the default `RoiArray` are ready.
%- You want per-ROI fluorescence traces before dF/F computation or
%  deconvolution.
%
%What happens:
%- NANSEN loads the motion-corrected stack and the default ROI array.
%- For each ROI, fluorescence is extracted from the ROI region and configured
%  neuropil regions.
%- Signal metadata such as sample rate are inherited from the image stack
%  where available.
%
%Outputs:
%- `RoiSignals_MeanF`: mean ROI fluorescence traces.
%- `RoiSignals_NeuropilF`: neuropil fluorescence traces.
%- `OptionsSignalExtraction`: options used for the extraction run.

    properties (Constant) % SessionMethod attributes
        MethodName = 'Extract Signals'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class')) % todo...
    end

    properties (Constant)
        DATA_SUBFOLDER = 'roisignals' % defined in nansen.processing.DataMethod
        VARIABLE_PREFIX	= 'RoiSignals'          % defined in nansen.processing.DataMethod
    end

    properties
        RequiredVariables = {'TwoPhotonSeries_Corrected', 'roiArray'}
    end

    methods (Static)
        function S = getDefaultOptions()
            S = nansen.twophoton.roisignals.extract.getDefaultParameters();
        end
    end

    methods

        function obj = extractSignals(varargin)

            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
    end

    methods

        function runMethod(obj)

            sessionData = nansen.session.SessionData(obj.SessionObjects);
            sessionData.updateDataVariables()

            imageStack = sessionData.TwoPhotonSeries_Corrected;

            roiArray = sessionData.RoiArray;

            extractF = @nansen.twophoton.roisignals.extractF;
            [signalArray, P] = extractF(imageStack, roiArray, 'verbose', true, obj.Options);

            % Todo: Save results...
            obj.saveData('RoiSignals_MeanF', squeeze(signalArray(:, 1, :)) )
            obj.saveData('RoiSignals_NeuropilF', squeeze(signalArray(:, 2:end, :)) )

            obj.saveData('OptionsSignalExtraction', P, ...
                'Subfolder', 'roisignals', 'IsInternal', true)

            % Inherit metadata from image stack
            fileAdapter = obj.SessionObjects.getFileAdapter('RoiSignals_MeanF');
            fileAdapter.setMetadata('SampleRate', imageStack.getSampleRate(), 'Data')
            %fileAdapter.setMetadata('StartTimeNum', imageStack.getStartTime('number'), 'Data')
            %fileAdapter.setMetadata('StartTimeStr', imageStack.getStartTime('string'), 'Data')
        end
    end

    methods
        function printTask(obj, varargin)
            fprintf(varargin{:})
        end
    end
end
