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
    
    varName = sessionData.uiSelectVariableName('RoiArray');

    if ~isempty(varName)
        roiArray = sessionData.(varName{1});
    else
        return
    end
    
    try
        
        roiGroup = getRoiGroup(sessionObject, roiArray, varName{1});

        if isempty(roiGroup)
            imageStack = sessionData.TwoPhotonSeries_Corrected;
            hClassifier = roiclassifier.openRoiClassifier(roiArray, imageStack);
        else
            hClassifier = roiclassifier.openRoiClassifier(roiGroup);
        end
            
        hClassifier.dataFilePath = sessionObject.getDataFilePath('RoiArray');
    
        % Todo: uiwait and then retrieve results and save when closing?
        
        
    catch ME
        throw(ME)
    end
end


function S = getDefaultParameters()
    
    S = struct();
    % Add more fields:

end


function roiGroup = getRoiGroup(sessionObject, roiArray, roiVariableName)

        roiGroup = [];
        
        filePath = sessionObject.getDataFilePath(roiVariableName);
        
        S = load(filePath);
        
        if isfield(S, 'roiImages')
            roiArray = roiArray.setappdata('roiImages', S.roiImages);
        else
            return
        end
        
        if isfield(S, 'roiStats')
            roiArray = roiArray.setappdata('roiStats', S.roiStats);
        else
            return
        end
        
        if isfield(S, 'roiClassification')
            roiArray = roiArray.setappdata('roiClassification',  S.roiClassification);
        else
            roiClassification = zeros(1, numel(roiArray));
            roiArray = roiArray.setappdata('roiClassification',  roiClassification);
        end
        
        roiGroup = roimanager.roiGroup(roiArray);

end