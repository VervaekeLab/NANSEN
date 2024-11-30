function varargout = twoPhotonRawImages(sessionObj, varargin)
%twoPhotonRawImages Open 2-photon raw recording in imviewer
%
%   twoPhotonRawImages(sessionObj) opens the raw two-photon recording for
%   the given session using default options.
%
%   twoPhotonRawImages(sessionObj, Name, Value) opens the recording using
%   the options given as name, value pairs.
%
%   fcnAttributes = twoPhotonRawImages() returns a struct of attributes for
%   the function.

%   Todo: Implement dynamic retrieval of parameters based on file adapter
%   for opening files.

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
    
    filePath = sessionObj.getDataFilePath('TwoPhotonSeries_Original');
    
    if ~isfile(filePath)
        error('File for "%s" was not found.', 'TwoPhotonSeries_Original')
    end
    
    if ~params.UseVirtualStack
        imageStack = nansen.stack.ImageStack(filePath);
        imData = imageStack.getFrameSet(params.FirstImage:params.LastImage);
        imviewer(imData)
        
    else
        imageStack = sessionObj.loadData('TwoPhotonSeries_Original');
        numStacks = numel(imageStack);
        
        if numStacks > 1
            % Let user select one or more image stacks if multiple stacks
            % are found (i.e multi FOV (mesoscope) imaging).
            alternatives = arrayfun(@(i) sprintf('Fov %d', i), 1:numStacks, 'uni', 0);
            [selectionInd, ~] = listdlg(...
                'ListString', alternatives, ...
                'SelectionMode', 'multi'); 
        else
            selectionInd = 1;
        end
        
        for i = selectionInd
            imviewer(imageStack(i))
        end
    end
end

function S = getDefaultParameters()
    S = struct();
    S.UseVirtualStack = true;
    S.FirstImage = 1;
    S.LastImage = inf;
end
