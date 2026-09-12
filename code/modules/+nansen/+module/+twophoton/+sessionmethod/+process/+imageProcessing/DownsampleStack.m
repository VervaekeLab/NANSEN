function varargout = DownsampleStack(sessionObject, varargin)
%Create a temporally downsampled copy of an image stack.
%
%Use this when:
%- You need a smaller stack for quick inspection, algorithm testing, or
%  lightweight downstream processing.
%- You want to bin frames over time while preserving the original image
%  height, width, channel count, and data type.
%
%What happens:
%- NANSEN loads the selected stack variable.
%- Consecutive groups of frames are binned with the selected method.
%- The downsampled stack is saved to file by the stack processor.
%
%Outputs:
%- A temporally downsampled ImageStack file is created according to the
%  selected downsampling factor and binning method.

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify one or
% more attributes (see nansen.session.SessionMethod.setAttributes) for
% details.

    % Get struct of parameters from local function
    params = getDefaultParameters();

    % Create a cell array with attribute keywords
    ATTRIBUTES = {'serial', 'queueable'};

% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % %
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - -

    % Create a struct with "attributes" using a predefined pattern
    import nansen.session.SessionMethod
    fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});

    if ~nargin && nargout > 0
        varargout = {fcnAttributes};   return
    end

    % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, [], varargin);

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Implementation of the session method.

    imageStack = sessionObject.loadData(params.StackName);

    n = params.DownsamplingFactor;
    binMethod = params.BinningMethod;

    %options = {'SaveToFile', true, 'UseTransientVirtualStack', false};
    %imageStack.downsampleT(n, binMethod, options{:});

    options = {'SaveToFile', true, 'UseTemporaryFile', false};
    nansen.stack.processor.TemporalDownsampler(imageStack, n, binMethod, options{:});
end

function S = getDefaultParameters()

    S = struct();
    S.StackName = 'TwoPhotonSeries_Corrected'; % ImageStack variable to downsample.
    S.StackName_ = {'TwoPhotonSeries_Corrected'};
    S.DownsamplingFactor = 10; % Number of consecutive frames per output frame.
    S.BinningMethod = 'mean';  % Method used to combine frames within each bin.
    S.BinningMethod_ = {'mean', 'max'};
end
