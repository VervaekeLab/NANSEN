function [P, V] = getDffParameters()
%getDffParameters Get parameters for signal deconvolution
%
%   P = nansen.twophoton.roisignals.getDffParameters() returns 
%       a struct (P) with default parameters for computation of DFF
%
%   [P, V] = nansen.twophoton.roisignals.getDffParameters() 
%       returns an additional struct (V) containing assertions for each 
%       parameter, for use with an input parser etc.
%
%   SELECTED PARAMETERS:
%   --------------------
%
%
%   Note: for full list of parameters, run function without output, i.e
%       nansen.twophoton.roisignals.getDffParameters()



% DESRIPTION:
%   Change these parameters to change the behavior of the deconvolution
%   method.

    % - - - - - - - - Specify parameters and default values - - - - - - - - 
    
    % Names                     Values (default)        Description
    P                           = struct;
    P.baseline                  = 20;
    P.dffFcn                    = 'dffClassic';
    P.correctBaseline           = false;                % Moving baseline?
    P.correctionWindowSize      = 500;                  % Number of samples
    P.correctionPrctile         = 25;                   

    
    % - - - - - - - - - - Specify customization flags - - - - - - - - - - -
    P.dffFcn_                   = getDffMethodChoices();
    P.correctionPrctile_        = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 100, 'nTicks', 101, 'TooltipPrecision', 0}});

    
    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
    V.baseline                  = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x && x <= 100, ...
                                    'Value must be a scalar, non-negative number between 0 and 100' );
    
    V.dffFcn                    = @(x) assert(any(strcmp(x, P.dffFcn_)), ...
                                    sprintf('modelType must be either of: %s', strjoin(P.dffFcn_, ',')));
    V.correctBaseline           = @(x) assert( isscalar(x) && islogical(x) , ...
                                    'Value must be a scalar logical' );
    V.correctionWindowSize      = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x, ...
                                    'Value must be a scalar, non-negative, integer number' );
    V.correctionPrctile         = @(x) assert( isnumeric(x) && isscalar(x) && x >= 0 && round(x)==x && x <= 100, ...
                                    'Value must be a scalar, non-negative number between 0 and 100' );


    % - - - - - Adapt output to how many outputs are requested - - - - - -
    
    if nargout == 0
        displayParameterTable(mfilename('fullpath'))
        
%         S = utility.convertParamsToStructArray(mfilename('fullpath'));
%         T = struct2table(S);
%         fprintf('\nSignal extraction default parameters and descriptions:\n\n')
%         disp(T)
        
        clear P V
    elseif nargout == 1
        clear V
    end
    
end

function choices = getDffMethodChoices()
    
    persistent fileNames
    
    if isempty(fileNames)
        
        s = what(fullfile('+nansen', '+twophoton', '+roisignals', '+process', '+dff'));
        dirPath = s.path;

        L = dir(fullfile(dirPath, '*.m'));
        fileNames = {L.name};
        fileNames = strrep(fileNames, '.m', '');
    end
    
    choices = fileNames; 
end
