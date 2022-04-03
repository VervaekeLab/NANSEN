function varargout = DownsampleStack(sessionObject, varargin)
%DOWNSAMPLESTACK Summary of this function goes here
%   Detailed explanation goes here


% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % 
% Create a struct of default parameters (if applicable) and specify one or 
% more attributes (see nansen.session.SessionMethod.setAttributes) for 
% details.
    
    % Get struct of parameters from local function
    params = getDefaultParameters();
    
    % Create a cell array with attribute keywords
    ATTRIBUTES = {'batch', 'queueable'};   

    
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
    
    imageStack = sessionObject.loadData(params.StackName);
        
    n = params.DownsamplingFactor;
    binMethod = params.BinningMethod;
    
    imageStack.downsampleT(n, binMethod, 'SaveToFile', true);

end


function S = getDefaultParameters()
    
    S = struct();
    S.StackName = 'TwoPhotonSeries_Corrected';
    S.StackName_ = {'TwoPhotonSeries_Corrected'};
    S.DownsamplingFactor = 10;
    S.BinningMethod = 'mean';
    S.BinningMethod_ = {'mean', 'max'};

end