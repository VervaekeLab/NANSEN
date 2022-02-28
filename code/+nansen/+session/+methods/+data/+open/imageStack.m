function varargout = imageStack(sessionObj, varargin)
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
    ATTRIBUTES = {'serial', 'queueable'};
    
    
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
        
    filePath = sessionObj.getDataFilePath(params.VariableName);
    
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
    
    global dataFilePathModel
    if isempty(dataFilePathModel)
        dataFilePathModel = nansen.setup.model.FilePathSettingsEditor;
    end
    
    % Todo: This is project dependent, can not be part of nansen package
    % session methods.
    
    fileAdapters = {dataFilePathModel.VariableList.FileAdapter};
    isImageStack = contains(fileAdapters, 'ImageStack');
    
    varNames = {dataFilePathModel.VariableList(isImageStack).VariableName};
    
    if isempty(varNames); varNames = {'N/A'}; end
    
    S = struct();
    S.VariableName = varNames{1};
    S.VariableName_ = varNames;
    
    S.UseVirtualStack = true;
    S.FirstImage = 1;
    S.LastImage = inf;
    
end