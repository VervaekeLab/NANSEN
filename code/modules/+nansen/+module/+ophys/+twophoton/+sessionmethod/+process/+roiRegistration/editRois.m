function varargout = editRois(sessionObject, varargin)
%Edit longitudinal ROIs across a selected session set.
%
%Use this when:
%- You have migrated ROIs across sessions and want to manually correct the
%  matched ROI set.
%- You need to switch between sessions while keeping RoiManager focused on
%  the corresponding longitudinal ROIs.
%
%What happens:
%- NANSEN loads an FOV projection for each selected session.
%- It loads `RoiArrayLongitudinal` and the selected ImageStack for each
%  session.
%- RoiManager opens on the first session, together with a multi-session FOV
%  switcher for moving through the selected sessions.
%
%Outputs:
%- ROI edits are managed by RoiManager and the multi-session switcher.

% Todo: Also support loading of roi classifications.
%   Specify FOV image variable name in parameters.

% % % % % % % % % % % % CONFIGURATION CODE BLOCK % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify one or
% more attributes (see nansen.session.SessionMethod.setAttributes)
    
    % Get struct of parameters from local function
    params = getDefaultParameters();
    
    % Create a cell array with attribute keywords
    ATTRIBUTES = {'batch', 'unqueueable'};
    
% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % %
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - -
    
    % Create a struct with "attributes" using a predefined pattern
    import nansen.session.SessionMethod
    fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
    
    if ~nargin && nargout > 0
        varargout = {fcnAttributes};   return
    end
    
    % Parse name-value pairs from function input and update parameters
    params = utility.parsenvpairs(params, [], varargin);
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
    
    % - Load FOV images for all sessions

    numSessions = numel(sessionObject);
    fovImages = cell(1, numSessions);

    for i = 1:numSessions
        if sessionObject(i).existVariable('FovAverageProjection')
            thisFovImage = sessionObject(i).loadData('FovAverageProjection');
        elseif sessionObject(i).existVariable('FovAverageProjectionCorr')
            thisFovImage = sessionObject(i).loadData('FovAverageProjectionCorr');
        else
            throwError('MultiDayRoiEdit:FovMissing', sessionObject(i).sessionID)
        end
        thisImage = thisFovImage.getFrameSet(1);
        if thisFovImage.NumChannels == 2
            thisImage = cat(3, thisImage, thisImage(:,:,1));
        end
        fovImages{i} = thisImage;
    end

    % - Get multisession rois
    sessionObjectStruct = struct();

    for i = 1:numel(sessionObject) % Todo: use s.Data instead.
        sessionObjectStruct(i).sessionID = sessionObject(i).sessionID;
        sessionObjectStruct(i).ImageStack = sessionObject(i).loadData( params.ImageStackVariableName );
        sessionObjectStruct(i).RoiArray = sessionObject(i).loadData('RoiArrayLongitudinal');
        sessionObjectStruct(i).FovImage = fovImages{i};
    end

    % - Open roimanager and the multisession FOV switcher
    roimanagerApp = roimanager.RoimanagerDashboard(sessionObjectStruct(1).ImageStack);
    roimanagerApp.addRois(sessionObjectStruct(1).RoiArray)

    h = MultiSessionFovSwitcher(sessionObject, sessionObjectStruct, roimanagerApp);
    
    % Todo: Mount switcher in roimanager gui...
    
end

function params = getDefaultParameters()
    params = struct();
    params.ImageStackVariableName = 'TwoPhotonSeries_Corrected'; % ImageStack shown in RoiManager.

end

function throwError(errorID, sessionID)

    switch errorID
        case 'MultiDayRoiEdit:FovMissing'
            message = sprintf( [ 'Did not find FOV average projection ', ...
                'image for for session %s.\nPlease make sure an image ', ...
                'exists for all selected sessions.'], sessionID );
    end

    error(errorID, message) %#ok<SPERR>
end
