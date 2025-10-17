function varargout = openRoiManager(sessionObj, varargin)
%openRoimanager Open roimanager for corrected two-photon images
%

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Please create a struct of default parameters (if applicable) and specify
% one or more attributes (see nansen.session.SessionMethod.setAttributes)
% for details.

    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'unqueueable'};
    
% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % %
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - -

    % % % Initialization block for a session method function.
    fcnAttributes = nansen.session.SessionMethod.setAttributes(params, ATTRIBUTES{:});
    
    if ~nargin && nargout > 0
        varargout = {fcnAttributes};   return
    end
    
    % % % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, [], varargin);
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Implementation of the method : Add you code here:
        
    %sessionObj.validateVariable('TwoPhotonSeries_Corrected')

% %     filepath = fullfile(nansen.toolboxdir, 'resources', 'images', 'nansen_roiman.png');
% %     [jFrame, jLabel, C] = nansen.ui.showSplashScreen(filepath, 'RoiManager'); %#ok<ASGLU>
% %     jLabel.setText('Retrieving Session Data')
    
    sessionData = nansen.session.SessionData( sessionObj );
    sessionData.updateDataVariables()

    if ~isprop(sessionData, 'TwoPhotonSeries_Corrected')
        error('Did not find "TwoPhotonSeries_Corrected" for session.')
    end

% %     jLabel.setText('Opening Image Stack')

    imageStack = sessionData.TwoPhotonSeries_Corrected;
    imageStack.DynamicCacheEnabled = true;
    
    hRoimanager = nansen.roimanager(imageStack);
    
    try
% %         roiFilePath = sessionObj.getDataFilePath('RoiArray');
% %         if ~isfile(roiFilePath)
            
        varName = sessionData.uiSelectVariableName('roiArray', 'single');
        if ~isempty(varName)
            if isa(varName, 'cell'); varName = varName{1}; end
            roiFilePath = sessionObj.getDataFilePath(varName);
            
            if ~isfile(roiFilePath)
                return
            else
    %             jLabel.setText('Loading rois')
                hRoimanager.loadRois(roiFilePath)
                hRoimanager.DataSet = sessionData;
            end
        end
% %        end

    catch ME
        disp(getReport(ME))
        return
    end
end

function S = getDefaultParameters()

    S = struct();
    
end
