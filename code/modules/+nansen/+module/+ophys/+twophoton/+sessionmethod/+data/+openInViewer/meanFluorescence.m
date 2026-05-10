function varargout = meanFluorescence(sessionObject, varargin)
%View extracted mean-fluorescence ROI signals for this session.
%
%Use this when:
%- You have already extracted ROI signals from the motion-corrected stack.
%- You want to inspect raw fluorescence traces before neuropil correction,
%  delta-F-over-F computation, or deconvolution.
%
%What happens:
%- NANSEN loads `RoiSignals_MeanF`.
%- The signals are opened in the interactive SignalViewer app.
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
    ATTRIBUTES = {'serial', 'unqueueable', 'MethodName', 'View Mean Fluorescence'};
    
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
    
    sessionObject.validateVariable('RoiSignals_MeanF')
    roiSignalArray = sessionObject.loadData('RoiSignals_MeanF');
    signalviewer.App(roiSignalArray)

end

function S = getDefaultParameters()
    
    S = struct();

end
