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
    
    % - Load roi array
    roiArray = sessionObject.loadData('RoiArrayLongitudinal');

    % - Get imagestack
    imageStack = sessionObject.loadData( params.ImageStackVariableName );

    % - Configure an imagestack iterator to iterate over channels & planes
    numC = imageStack.NumChannels;
    numZ = imageStack.NumPlanes;
    stackIterator = nansen.stack.ImageStackIterator(numC, numZ);

    % 
    [numZ_, numC_] = size(roiArray);
    assert( (numC==numC_) && (numZ==numZ_), 'Size of roi array does not match size of image stack.')
    
    [roiImages, roiStats] = deal( cell(numZ, numC) );
    
    N = obj.SourceStack.chooseChunkLength();
    

    stackIterator.reset()
    for i = 1:stackIterator.NumIterations
        stackIterator.next()
        
        iC = stackIterator.CurrentIterationC;
        iZ = stackIterator.CurrentIterationZ;
        
        thisRoiArray = roiArray{iZ, iC};
        
        % Load images:
        imageStack.CurrentChannel = stackIterator.CurrentChannel;
        imageStack.CurrentPlane = stackIterator.CurrentPlane;
        
        imArray = imageStack.getFrameSet(1:N);
        % Todo: Include this but fix caching for multichannel data...
        % obj.SourceStack.addToStaticCache(imArray, 1:N)
        imArray = squeeze(imArray);

        if ~isempty(thisRoiArray)
            [roiImages, roiStats] = getRoiAppData(imArray, thisRoiArray); % Imported function

            roiImages{iZ, iC} = roiImages;
            roiStats{iZ, iC} = roiStats;
        end
    end

    % Collect data and save roigroup

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