function varargout = DenoiseStack(sessionObject, varargin)
%Denoise an image stack with DeepInterpolation.
%
%Use this when:
%- You want to suppress frame-wise noise in an ImageStack before visual
%  inspection or downstream processing.
%- You have MATLAB R2023a or newer and the Deep Learning Toolbox Converter
%  for TensorFlow Models available.
%
%What happens:
%- You choose which ImageStack variable to denoise.
%- NANSEN runs the stack denoiser with the configured DeepInterpolation
%  window and stack-processing options.
%- The current implementation uses the pretrained two-photon model from the
%  DeepInterpolation MATLAB workflow.
%
%Outputs:
%- A denoised stack is produced by the stack processor according to the
%  selected export options.
%
%References:
%- https://github.com/AllenInstitute/deepinterpolation
%- https://github.com/MATLAB-Community-Toolboxes-at-INCF/DeepInterpolation-MATLAB

% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Create a struct of default parameters (if applicable) and specify one or
% more attributes (see nansen.session.SessionMethod.setAttributes) for
% details.
    
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
    
    % Parse name-value pairs from function input.
    params = utility.parsenvpairs(params, [], varargin);
    
% % % % % % % % % % % % % % CUSTOM CODE BLOCK % % % % % % % % % % % % % %
% Implementation of the session method.
    
    imageStack = sessionObject.loadData(params.Input.VariableName);
    params = utility.struct.renamefield(params, 'StackOptions', 'Run');
    nansen.stack.processor.Denoiser(imageStack, params);
end

function S = getDefaultParameters()
    methodOptions = nansen.stack.processor.Denoiser.getDefaultOptions();
    
    variableNameOptions = getVariableNameAlternatives();
    inputOptions = struct;
    inputOptions.Input.VariableName = variableNameOptions{1};
    inputOptions.Input.VariableName_ = variableNameOptions;
    
    S = utility.struct.mergestruct(inputOptions, methodOptions);
    S = utility.struct.renamefield(S, 'Run', 'StackOptions');
end

function varNames = getVariableNameAlternatives()
%getVariableNameAlternatives Collect a list of imagestack variables
    variableModel = nansen.VariableModel();
    varNames = variableModel.getVariableNamesOfType('ImageStack');
    if isempty(varNames); varNames = {'N/A'}; end
end
