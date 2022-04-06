function varargout = DeconvolutionCaImAn(sessionObject, varargin)
%DECONVOLUTIONCAIMAN Summary of this function goes here
%   Detailed explanation goes here


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
    params = utility.parsenvpairs(params, 1, varargin);
    
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % 
% Implementation of the method : Add your code here:    
       

    sessionObject.validateVariable('RoiResponsesDff')
    signalArray = sessionObject.loadData('RoiResponsesDff');
    deconvolved = nansen.twophoton.roisignals.deconvolveDff(signalArray, params);
    sessionObject.saveData('RoiResponsesDeconvolved', deconvolved, 'Subfolder', 'roisignals')
    
    % Todo: Save denoised.

    % Todo: Save parameters.

end


function S = getDefaultParameters()
    
    [S, V] = nansen.twophoton.roisignals.getDeconvolutionParameters();

end