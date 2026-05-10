function varargout = imageStack(sessionObj, varargin)
%Open any image-stack data variable from this session in imviewer.
%
%Use this when:
%- You want to inspect an ImageStack variable without running processing.
%- You need to choose between raw, motion-corrected, denoised, downsampled,
%  or other ImageStack variables registered in the active variable model.
%
%What happens:
%- NANSEN builds one menu alternative for each ImageStack variable.
%- With `UseVirtualStack` enabled, imviewer reads frames lazily from disk.
%- With `UseVirtualStack` disabled, only `FirstImage` through `LastImage`
%  are loaded into memory before opening imviewer.
%
%Outputs:
%- No data are written; this method only opens an interactive viewer.

import nansen.session.SessionMethod

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify
% one or more attributes (see nansen.session.SessionMethod.setAttributes)
% for details.

    % % % Get struct of default parameters for function.
    params = getDefaultParameters();
    ATTRIBUTES = {'serial', 'unqueueable'};
    
    % Get all the data variable alternatives for this function. Add it to
    % the optional 'Alternatives' attribute to autogenerate a menu item for
    % each variable that can be opened as an imagestack object in imviewer.
    variableNames = getVariableNameAlternatives();
    ATTRIBUTES = [ATTRIBUTES, {'Alternatives', variableNames}];

% % % % % % % % % % % % % DEFAULT CODE BLOCK % % % % % % % % % % % % % %
% - - - - - - - - - - Please do not edit this part - - - - - - - - - - -
   
    % % % Initialization block for a session method function.

    if ~nargin && nargout > 0
        fcnAttributes = SessionMethod.setAttributes(params, ATTRIBUTES{:});
        varargout = {fcnAttributes};   return
    end
    
    params.Alternative = variableNames{1}; % Set a default value.

    % % % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, [], varargin);
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Implementation of the method : Add you code here:
        
    imageStack = sessionObj.loadData(params.Alternative);

    if ~params.UseVirtualStack
        if params.LastImage > imageStack.NumTimepoints
            frameIndices = params.FirstImage:imageStack.NumTimepoints;
        else
            frameIndices = params.FirstImage:params.LastImage;
        end
        
        imData = imageStack.getFrameSet(frameIndices);
        imviewer(imData)
    else
        
        imviewer(imageStack)
    end
end

function S = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    S = struct();
    
    S.UseVirtualStack = true; % Open the stack lazily from disk when possible.
    S.FirstImage = 1;         % First frame to load when UseVirtualStack is false.
    S.LastImage = inf;        % Last frame to load when UseVirtualStack is false.
end

function alternatives = getVariableNameAlternatives()
%getVariableNameAlternatives Collect a list of imagestack variables
    
    variableModel = nansen.VariableModel();

    dataTypes = {variableModel.Data.DataType};
    isImageStack = contains(dataTypes, 'ImageStack');
    varNames = {variableModel.Data(isImageStack).VariableName};
    if isempty(varNames); varNames = {'N/A'}; end
    
    alternatives = varNames;
end
