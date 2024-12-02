function varargout = viewDff(sessionObject, varargin)
%VIEWDFF Open dff (delta f over f) roi signals in SignalViewer app. 
%
%   VIEWDFF opens the delta F over F in an interactive viewer.

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
% Implementation of the method : Add your code here:
    
    sessionObject.validateVariable('RoiSignals_Dff')
    roiSignalArray = sessionObject.loadData('RoiSignals_Dff');
    roiSignalArray = roiSignalArray(:, 'RoiSignals_Dff');
    
    signalviewer.App(roiSignalArray)

end

function S = getDefaultParameters()
    
    S = struct();
    % Add more fields:

end
