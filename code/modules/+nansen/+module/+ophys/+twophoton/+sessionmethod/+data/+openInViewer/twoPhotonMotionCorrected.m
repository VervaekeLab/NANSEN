function varargout = twoPhotonMotionCorrected(sessionObj, varargin)
%TWOPHOTONMOTIONCORRECTED Open 2-photon corrected recording in imviewer
%
%   Opens the motion-corrected two-photon recording for the given session 
%   using default options.

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Please create a struct of default parameters (if applicable) and specify
% one or more attributes (see nansen.session.SessionMethod.setAttributes)
% for details.

    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'unqueueable', 'MethodName', 'View Motion-Corrected 2-Photon'};
    
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
        
    filePath = sessionObj.getDataFilePath('TwoPhotonSeries_Corrected');
    
    if ~isfile(filePath)
        error('File for "%s" was not found.', 'TwoPhotonSeries_Corrected')
    end
    
    if ~params.UseVirtualStack
        imageStack = nansen.stack.ImageStack(filePath);
        imData = imageStack.getFrameSet(params.FirstImage:params.LastImage);
        imviewer(imData)
        
    else
        imviewer(filePath)
    end
end

function params = getDefaultParameters()
    params = struct();
    params.UseVirtualStack = true; % Whether to open the stack without loading data into memory (virtual stack).
    params.FirstImage = uint64(1); % Index of first frame to load if UseVirtualStack is false
    params.LastImage = inf;        % Index of last frame to load if UseVirtualStack is false
end
