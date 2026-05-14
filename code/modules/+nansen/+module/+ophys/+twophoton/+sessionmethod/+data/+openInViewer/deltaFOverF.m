function varargout = deltaFOverF(sessionObject, varargin)
%View delta-F-over-F ROI signals for this session.
%
%Use this when:
%- You have already run signal extraction and delta-F-over-F computation.
%- You want to inspect normalized ROI activity traces in SignalViewer.
%
%What happens:
%- NANSEN checks that `RoiSignals_Dff` exists for the selected session.
%- The `RoiSignals_Dff` column is opened in the interactive SignalViewer app.
%
%Outputs:
%- No data are written; this method only opens an interactive viewer.

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify one or
% more attributes (see nansen.session.SessionMethod.setAttributes) for
% details.

    % Get struct of parameters from local function
    params = getDefaultParameters();

    % Create a cell array with attribute keywords
    ATTRIBUTES = {'serial', 'unqueueable'};

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

    sessionObject.validateVariable('RoiSignals_Dff')
    roiSignalArray = sessionObject.loadData('RoiSignals_Dff');
    roiSignalArray = roiSignalArray(:, 'RoiSignals_Dff');

    signalviewer.App(roiSignalArray)
end

function S = getDefaultParameters()

    S = struct();
end
