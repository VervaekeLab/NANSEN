function varargout = imageStack(sessionObj, varargin)
%imageStack Open image stack data variable in imviewer
%
%   imageStack(sessionObj) opens the first imagestack variable for
%   the given session using default options.
%
%   imageStack(sessionObj, Name, Value) opens an imagestack using
%   the options given as name, value pairs.
%
%   fcnAttributes = imageStack() returns a struct of attributes for
%   the function.
%
%   List of options (name, value pairs):
%        
%       VariableName    : Name of data variable to open in imviewer
%       UseVirtualStack : Boolean flag, open using virtual stack or not
%       FirstImage      : First image to load (if UseVirtualStack is false)
%       LastImage       : Last image to load (if UseVirtualStack is false)

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
        
    filePath = sessionObj.getDataFilePath(params.Alternative);
    
    if ~params.UseVirtualStack
        imageStack = nansen.stack.ImageStack(filePath);
        
        if params.LastImage > imageStack.NumTimepoints
            frameIndices = params.FirstImage:imageStack.NumTimepoints;
        else
            frameIndices = params.FirstImage:params.LastImage;
        end
        
        imData = imageStack.getFrameSet(frameIndices);
        imviewer(imData)
        
    else
        imviewer(filePath)
    end

end


function S = getDefaultParameters()
%getDefaultParameters Define the default parameters for this function
    S = struct();
    
    S.UseVirtualStack = true;
    S.FirstImage = 1;
    S.LastImage = inf;
    
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