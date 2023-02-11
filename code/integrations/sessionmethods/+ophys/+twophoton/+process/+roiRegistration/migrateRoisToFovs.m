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
    
    % Count number of sessions
    numSessions = numel(sessionObject);

    % Let user choose reference session
    sessionIDs = {sessionObject.sessionID};
    refSessionID = nansen.ui.dialog.uiSelectString(sessionIDs, 'single', 'reference session');
    if isempty(refSessionID); return; end % User canceled
    
    % Reorder sessions to place the reference session first in the list.
    idx = find(strcmp(refSessionID, sessionIDs));
    newOrder = unique( [idx, 1:numSessions], "stable" );
    sessionObject = sessionObject(newOrder); 
    sessionIDs = sessionIDs(newOrder);

    % Initialize a struct array

    % Load all fov images
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

        if thisFovImage.NumPlanes > 1
            error('Not implemented for multiplane imaging sessions yet.')
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
    roiArray = sessionObject(1).loadData(varName{1}, 'FileAdapter', 'nansen.internal.dataio.fileadapter.RoiArray');

    if ~isa(roiArray, 'cell'); roiArray = {roiArray}; end

    [flatRoiArray, numRois] = utility.cell.flatten(roiArray);

    flatRoiArray = roimanager.utilities.struct2roiarray(flatRoiArray);

    % Shift rois for each session based on shifts from image registration
    roiArrayMigrated = cell(1, numSessions-1);
    for i = 1:numSessions-1
        warpedRois = flufinder.longitudinal.warpRois(flatRoiArray, fovShifts(i));
        roiArrayMigrated{i} = utility.cell.unflatten(warpedRois, numRois);
    end

    % Get save folder
    rootFolder = fileparts(sessionObject(1).getSessionFolder());
    saveFolder = fullfile(rootFolder, 'longitudinal_roi_registration', ...
                    sprintf('reference_session_%s', sessionIDs{1}));
    if ~isfolder(saveFolder); mkdir(saveFolder); end

    % Todo: Do this per plane and channel?
    numChannels = size(roiArray, 2);
    channelColors = cbrewer('qual', 'Pastel1', max([3, numChannels]));
    hRois = cell(1, numChannels);

    % Show results
    [imageHeight, imageWidth, ~] = size(fovImageArray);
    figureSize = [imageHeight, imageWidth];
    hFigure = figure('MenuBar', 'none', 'Position', [1,1,figureSize]);
    hAxes = axes(hFigure, 'Position', [0,0,1,1]);

    for i = 1:numSessions
        
        fileName = sprintf('fov_roi_registration_%s.png', sessionIDs{i});
        savePath = fullfile(saveFolder, fileName);
        
        if i == 1 % Reference session
            hImage = imshow(uint8(fovImageArray(:, :, 1)));
            hold(hAxes, 'on')
            
            thisRoiArray = roiArray;
        else
            hImage.CData = uint8( fovImageArray(:, :, i) );
            cellfun(@delete, hRois)
            thisRoiArray = roiArrayMigrated{i-1};
        end
        
        for jChannel = 1:numChannels
            hRois{jChannel} = imviewer.plot.plotRoiArray(hAxes, thisRoiArray{jChannel});
            set(hRois{jChannel}, 'Color', channelColors(jChannel,:))
        end
        
        % Add legend for roi channels
        legendLines = cellfun(@(c) c(1), hRois);
        legendLabels = arrayfun(@(i) sprintf('Rois Channel %d', i), 1:numChannels, 'uni', 0);
        hLegend = legend(hAxes, legendLines, legendLabels, 'AutoUpdate', 'off');
        hLegend.Box = 'off';
        hLegend.TextColor = [0.9,0.9,0.9];
        hLegend.FontSize = 10;

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
    
    % todo: rois is a vector/matrix (i.e multichannel/plane)
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
        if isa(thisRoiArray, 'cell')
            iZ = 1;
            iC = params.WorkingChannel;
            trackedRoiArray = thisRoiArray{iZ, iC};
        else
            trackedRoiArray = thisRoiArray;
        end
        
        % Todo: Save working channel on multisessionrois

        S.multiSessionRois = S.multiSessionRois.addEntry(sessionIDs{i}, fovImageArray(:,:,i), trackedRoiArray);
        S.multiSessionRois(i).ImageChannel =  params.WorkingChannel;
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
    S.WorkingChannel = 2;
    S.WorkingChannel_ = {1,2};

    %  S.MultisessionRoiSynchMode ?
    % 'LoadFromMaster', struct('Alternatives', {{'Use Master', 'Use Single', 'Merge'}}, 'Selection', {'Merge'}), ...
    % 'SaveToMaster', struct('Alternatives', {{'Only Add', 'Mirror'}}, 'Selection', {'Mirror'}), ...

    % Add more fields:
end