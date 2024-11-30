function varargout = SelectRoiForSignalExtraction(sessionObject, varargin)
%SELECTROIFORSIGNALEXTRACTION Summary of this function goes here
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
    
    varName = sessionData.uiSelectVariableName('RoiArray', 'single');
    
    if ~isempty(varName)
        roiArray = sessionData.(varName{1});
    else
        return
    end

    if params.deleteRoisOutsideTheBorders

        outside = false(roiArray.roiCount,1);

        for roi = 1:1:roiArray.roiCount
            xOut = any( roiArray.roiArray(roi).coordinates(:,1) < 1) || any( roiArray.roiArray(roi).coordinates(:,1) > roiArray.FovImageSize(2) );
            yOut = any( roiArray.roiArray(roi).coordinates(:,2) < 1) || any( roiArray.roiArray(roi).coordinates(:,2) > roiArray.FovImageSize(1) );
            outside(roi) = xOut || yOut;
        end

        % outside = roiArray.roiArray.isOutsideImage(); % alternative
        % method but this checks the center

        roiArray.removeRois(find(outside))

    end
        
    sessionObject.saveData('RoiArray', roiArray)

end

function S = getDefaultParameters()
    
    S = struct();
    % Add more fields:
    S.deleteRoisOutsideTheBorders = true;

end
