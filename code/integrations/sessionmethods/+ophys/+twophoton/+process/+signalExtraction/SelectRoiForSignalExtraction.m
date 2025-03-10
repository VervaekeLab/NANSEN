function varargout = SelectRoiForSignalExtraction(sessionObject, varargin)
%SELECTROIFORSIGNALEXTRACTION Select which rois to use for signal extraction
%
% This method updates the default ROI data variable for a Nansen session. It 
% prompts the user to select which ROI variable to work with. If a valid 
% variable name is chosen, the corresponding ROI group is retrieved and
% saved to the default ROI variable.
%
% Note: The default ROI variable is used for signal extraction
%
% Parameters:
%   - deleteRoisOutsideTheBorders (logical) - 
%     Boolean flag true, determining if ROIs whose pixels lie partially or 
%     completely outside the field of view (FOV) boundaries are removed. The 
%     updated ROI group is then saved back to the session.

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
        roiGroup = sessionData.(varName{1});
    else
        return
    end
    
    if params.deleteRoisOutsideTheBorders

        for jGroup = 1:numel(roiGroup)
            outside = false(roiGroup(jGroup).roiCount, 1);
    
            for iRoi = 1:1:roiGroup(jGroup).roiCount   
                outside(iRoi) = hasPixelsOutsideImage(...
                    roiGroup(jGroup).roiArray(iRoi), ...
                    roiGroup(jGroup).FovImageSize);
            end
    
            % outside = roiArray.roiArray.isOutsideImage(); % alternative
            % method but this checks the center
    
            roiGroup(jGroup).removeRois(find(outside))
        end
    end

    sessionObject.saveData('RoiArray', roiGroup)
end

function isOutside = hasPixelsOutsideImage(roi, fovSize)
    xOut = any(roi.coordinates(:,1) < 1) || any(roi.coordinates(:,1) > fovSize(2));
    yOut = any(roi.coordinates(:,2) < 1) || any(roi.coordinates(:,2) > fovSize(1));
    isOutside = xOut || yOut;
end

function S = getDefaultParameters()
    S = struct();
    % Add more fields:
    S.deleteRoisOutsideTheBorders = true;
end
