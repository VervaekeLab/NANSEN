function [P, V] = defaultOptions()
%Template


% DESCRIPTION:
%   Change these parameters to change the behavior of the deconvolution
%   method.

    % - - - - - - - - Specify parameters and default values - - - - - - - - 
    
    % Names                       Values (default)      Description
    P                           = struct();             %
    
      
    
    
    
    
    % - - - - - - - - - - Specify customization flags - - - - - - - - - - -
 
    
    
    
    
    
    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
    
    
    % - - - - - Adapt output to how many outputs are requested - - - - - -
    
    if nargout == 0
        displayParameterTable(mfilename('fullpath'))
        clear P V
    elseif nargout == 1
        clear V
    end
    
end