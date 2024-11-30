function varargout = DenoiseStack(sessionObject, varargin)
%DenoiseStack Denoise an ImageStack using the DeepInterpolation method
%
%   This method is based on the DeepInterpolation method from the Allen
%   Institute. It requires MATLAB 2023a or later and the external toolbox
%   "Deep Learning Toolbox Converter for TensorFlow Models".
%
%   Note: Currently it uses the tretrained model they provided for two-photon
%   data. It is possible to train models (See the DeepInterpolation_Matlab)
%   on GitHub for details. Create an issue on VervaekeLab/Nansen if you
%   need help adapting the code to run with another model.
%
%   Input:
%       Input must be an ImageStack
%
%   Options:
%       PrePostOmission : How many frames around the target frame to omit
%           for the interpolation. Default = 0.
%
%       PreFrame : How many frames before the target frame to use for
%           interpolation. Default = 30.
%
%       PostFrame : How many frames after the target frame to use for
%           interpolation. Default = 30.
%
%   References:
%   (1) https://github.com/AllenInstitute/deepinterpolation
%   (2) https://github.com/MATLAB-Community-Toolboxes-at-INCF/DeepInterpolation-MATLAB

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
% Implementation of the method : Add your code here:
    
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
