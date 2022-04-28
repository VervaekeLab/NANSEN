function varargout = openRoiClassifier(sessionObject, varargin)
%OPENROICLASSIFIER Open roi classifier on a session
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
    
    varName = sessionData.uiSelectVariableName('roiArray');

    if ~isempty(varName)
        roiData = sessionData.(varName{1});
    else
        return
    end
    

    if ~isa(roiData, 'roimanager.roiGroup')
        roiGroup = getRoiGroup(sessionObject, roiData, varName{1});
    else
        roiGroup = roiData;
    end
    
    try
        if isempty(roiGroup)
            imageStack = sessionData.TwoPhotonSeries_Corrected;
            hClassifier = roiclassifier.openRoiClassifier(roiGroup, imageStack);
        else
            hClassifier = roiclassifier.openRoiClassifier(roiGroup);
        end

        hClassifier.dataFilePath = sessionObject.getDataFilePath('RoiArray'); % todo: varName{1}
    
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

        roiGroup = []; %#ok<NASGU>
        
        filePath = sessionObject.getDataFilePath(roiVariableName);
        roiFileAdapter = nansen.dataio.fileadapter.roi.RoiGroup(filePath);
        roiGroup = roiFileAdapter.load();
        
        % Todo: Create roi images and stats if they dont exist...

end