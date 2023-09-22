function varargout = computeClassificationData(sessionObject, varargin)
%computeClassificationData Summary of this function goes here
%   Detailed explanation goes here


% % % % % % % % % % % % CONFIGURATION CODE BLOCK % % % % % % % % % % % % 
% Create a struct of default parameters (if applicable) and specify one or 
% more attributes (see nansen.session.SessionMethod.setAttributes)
    
    % Get struct of parameters from local function
    params = getDefaultParameters();
    
    % Create a cell array with attribute keywords
    ATTRIBUTES = {'serial', 'queueable'};   

    
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
    
    
% % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % % %
        
    import nansen.twophoton.roi.compute.computeRoiImages
    import nansen.twophoton.roi.getRoiAppData
    % - Load roi array
    roiArray = sessionObject.loadData('RoiArrayLongitudinal');

    % - Get imagestack
    imageStack = sessionObject.loadData( params.ImageStackVariableName );

    % - Configure an imagestack iterator to iterate over channels & planes
    numC = imageStack.NumChannels;
    numZ = imageStack.NumPlanes;
    stackIterator = nansen.stack.ImageStackIterator(numC, numZ);

    % Check that size of roi array matches size of image stack (numC and numZ)
%     [numZ_, numC_] = size(roiArray);
%     assert( (numC==numC_) && (numZ==numZ_), ...
%         'Size of roi array does not match size of image stack.')
%                 
% 
    roiGroupCellArrayOfStruct = cell(numZ, numC);

    %[roiImages, roiStats] = deal( cell(numZ, numC) );
    
    N = imageStack.chooseChunkLength();

    stackIterator.reset()
    for i = 1:stackIterator.NumIterations
        stackIterator.next()
        
        iC = stackIterator.CurrentIterationC;
        iZ = stackIterator.CurrentIterationZ;
        
        thisRoiArray = roiArray{iZ, iC};
        if isa(thisRoiArray, 'struct')
            thisRoiArray = roimanager.utilities.struct2roiarray(thisRoiArray);
        end

        if ~isempty(thisRoiArray)
            imageStack.CurrentChannel = stackIterator.CurrentChannel;
            imageStack.CurrentPlane = stackIterator.CurrentPlane;
            
            % Load images:
            imArray = imageStack.getFrameSet(1:N);
            
            % Todo: Include this but fix caching for multichannel data...
            % obj.SourceStack.addToStaticCache(imArray, 1:N)
            imArray = squeeze(imArray);
    
            [roiImages, roiStats] = ...
                getRoiAppData(imArray, thisRoiArray); % Imported function
        else
            [roiImages, roiStats] = deal(struct.empty);
        end
        
        % Add all classification data the output struct
        thisRoiGroupStruct = struct();
        thisRoiGroupStruct.ChannelNumber = stackIterator.CurrentChannel;
        thisRoiGroupStruct.PlaneNumber = stackIterator.CurrentPlane;

        thisRoiGroupStruct.roiArray = thisRoiArray;
        thisRoiGroupStruct.roiImages = roiImages;
        thisRoiGroupStruct.roiStats = roiStats;
        thisRoiGroupStruct.roiClassification = zeros(numel(thisRoiArray), 1);

        roiGroupCellArrayOfStruct{iZ, iC} = thisRoiGroupStruct;
    end
    
    % Collect data and save roigroup
    roiGroupStruct = cell2mat(roiGroupCellArrayOfStruct);

    % Save as roigroup.
    sessionObject.saveData('RoiGroupLongitudinal', roiGroupStruct, ...
        'Subfolder', 'roi_data', 'FileAdapter', 'RoiGroup')
end


function params = getDefaultParameters()
%getDefaultParameters Get the default parameters for this session method
%
%   params = getDefaultParameters() should return a struct, params, which 
%   contains fields and values for parameters of this session method.

    % Add fields to this struct in order to define parameters for this
    % session method:
    params = struct();
    params.ImageStackVariableName = 'TwoPhotonSeries_Corrected';

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