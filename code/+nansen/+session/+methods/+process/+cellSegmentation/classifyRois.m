function varargout = classifyRois(sessionObject, varargin)
%CLASSIFYROIS Summary of this function goes here
%   Detailed explanation goes here


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
    
    
    sessionData = nansen.session.SessionData( sessionObject );
    sessionData.updateDataVariables()

    try
        imageStack = sessionData.TwoPhotonSeries_Corrected;
        roiArray = sessionData.RoiArray;

        hClassifier = roiclassifier.openRoiClassifier(roiArray, imageStack);
        hClassifier.dataFilePath = sessionObject.getDataFilePath('RoiArray');
    
    catch ME
        throw(ME)
    end
end


function S = getDefaultParameters()
    
    S = struct();
    % Add more fields:

end