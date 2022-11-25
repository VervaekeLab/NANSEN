function varargout = migrateRoisToFovs(sessionObject, varargin)
%MIGRATEROISTOFOV Summary of this function goes here
%   Detailed explanation goes here


% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % 
% Create a struct of default parameters (if applicable) and specify one or 
% more attributes (see nansen.session.SessionMethod.setAttributes) for 
% details.
    
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
    
    % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, [], varargin);
    
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % 
% Implementation of the method : Add your code here:    
    
    % Choose reference session
    sessionIDs = {sessionObject.sessionID};
    refSessionID = nansen.ui.dialog.uiSelectString(sessionIDs, 'single', 'reference session');
    if isempty(refSessionID); return; end % User canceled

    % Reorder sessions to place the reference session first in the list.
    % Todo...

    % Initialize a struct array

    % Load all fov images
    numSessions = numel(sessionObject);
    fovImages = cell(1, numSessions);
    for i = 1:numSessions
        if sessionObject(i).existVariable('FovAverageProjection')
            thisFovImage = sessionObject(i).loadData('FovAverageProjection');
        elseif sessionObject(i).existVariable('FovAverageProjectionCorr')
            thisFovImage = sessionObject(i).loadData('FovAverageProjectionCorr');
        else
            error(['Did not find Fov Average Projection image for session %s.\n', ...
                'Please make sure an image exists for all selected sessions.'], sessionIDs{i})
        end
        if thisFovImage.NumChannels > 1
            fovImages{i} = mean( thisFovImage.getFrameSet(1), 3 );
        else
            fovImages{i} = thisFovImage.getFrameSet(1);
        end

    end
    % Todo: If Fov is multi-channel, should we require all sessions to have
    % the same channels? Probably yes...

    % Store indices of missing sessions
    
    % Concatenate the fov images into an array
    fovImageArray = cat(3, fovImages{:});
    % Todo: Add method for concatenation if images are not the same size.


    % Register images for each fov/session to reference fov/session
    [fovShifts, imArrayNR] = flufinder.longitudinal.alignFovs(fovImageArray);

    % Load rois for reference session
    sessionData = sessionObject(1).Data;
    
    varName = sessionData.uiSelectVariableName('roiArray', 'single');
    roiArray = sessionObject(1).loadData(varName{1}, 'FileAdapter', 'nansen.dataio.fileadapter.roi.RoiArray');
    roiArray = roimanager.utilities.struct2roiarray(roiArray);

    % Shift rois for each session based on shifts from image registration
    roiArrayMigrated = cell(1, numSessions-1);
    for i = 1:numSessions-1
        roiArrayMigrated{i} = flufinder.longitudinal.warpRois(roiArray, fovShifts(i));
    end

    % Get save folder
    rootFolder = fileparts(sessionObject(1).getSessionFolder());
    saveFolder = fullfile(rootFolder, 'longitudinal_roi_registration', ...
                    sprintf('reference_session_%s', sessionIDs{1}));
    if ~isfolder(saveFolder); mkdir(saveFolder); end

    frame = cell(1, numSessions-1);
    % Show results
    
    [h, w, ~] = size(fovImageArray);
    hFigure = figure('MenuBar', 'none', 'Position', [1,1,w,h]);
    hAxes = axes(hFigure, 'Position', [0,0,1,1]);
    hImage = imshow(uint8(fovImageArray(:, :, 1)));
    hold(hAxes, 'on')
    hRois = imviewer.plot.plotRoiArray(hAxes, roiArray);
    
    for i = 1:numSessions
        
        fileName = sprintf('fov_roi_registration_%s.png', sessionIDs{i});
        savePath = fullfile(saveFolder, fileName);
        
        if i ~= 1
            hImage.CData = uint8( fovImageArray(:, :, i) );
            delete(hRois)
            hRois = imviewer.plot.plotRoiArray(hAxes, roiArrayMigrated{i-1});
        end
        print(hFigure, savePath, '-dpng', '-r300')
    end
    close(hFigure);
    L = dir( fullfile(saveFolder, 'fov_roi_registration_*.png') );

    imviewer( fullfile(saveFolder, {L.name}) )
    
    % Ask to save results
    % Todo

    % Initialize MultiSession Roi Array
    multiSessionRoiFilename = sprintf('%s_multi_session_roi_collection.mat', sessionIDs{1});
    multiSessionRoiFilepath = fullfile(saveFolder, multiSessionRoiFilename);
    
    % todo: rois is a vector (i.e multichannel/plane)
    S = struct;
    S.multiSessionRois = flufinder.longitudinal.MultiSessionRoiCollection.empty;
    %S.multiSessionRois = S.multiSessionRois.addEntry(sessionIDs{1}, fovImageArray(:,:,1), roiArray);
    %S.multiSessionRois = sortEntries(S.multiSessionRois);

    % Save results for all other sessions
    for i = 1:numSessions
        if i == 1
            thisRoiArray = roiArray;
        else
            % Todo: Ensure we are not overwriting data
            thisRoiArray = roiArrayMigrated{i-1};
        end
        S.multiSessionRois = S.multiSessionRois.addEntry(sessionIDs{i}, fovImageArray(:,:,i), thisRoiArray);
        sessionObject(i).saveData('RoiArrayLongitudinal', thisRoiArray, 'Subfolder', 'roi_data')
        sessionObject(i).saveData('MultisessionRoiCrossReference', multiSessionRoiFilepath, 'Subfolder', 'roi_data')
    end

    S.multiSessionRoisStruct = S.multiSessionRois.toStruct();
    save(multiSessionRoiFilepath, '-struct', 'S')
    fprintf('Rois saved to multi-session RoI file (%s) \n', multiSessionRoiFilepath);
end

function initializeMultiSessionRois()


end

function saveMultiSessionRois()
    

end

function S = getDefaultParameters()
    
    S = struct();
    %  S.MultisessionRoiSynchMode ?
    % 'LoadFromMaster', struct('Alternatives', {{'Use Master', 'Use Single', 'Merge'}}, 'Selection', {'Merge'}), ...
    % 'SaveToMaster', struct('Alternatives', {{'Only Add', 'Mirror'}}, 'Selection', {'Mirror'}), ...

    % Add more fields:
end