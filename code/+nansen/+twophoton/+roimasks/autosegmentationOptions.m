function [P, V] = autosegmentationOptions()

    % - - - - - - - - Specify parameters and default values - - - - - - - -
    
    % Names                       Values (default)      Description
    P                           = struct();             %
    P.autosegmentationMethod    = 'Quicky';             % Method for running autosegmentation
    P.autosegmentationMethod_   = {'Quicky', 'CaImAn-CNMF', 'Suite2p', 'EXTRACT'};
    P.options                   = [];
    P.options_                  = 'internal';
    P.editOptions               = false;
    P.editOptions_              = struct('type', 'button', 'args', {{'String', 'Edit Method Options', 'FontWeight', 'bold', 'ForegroundColor', [0.1840    0.7037    0.4863]}});
    P.firstFrame                = 1;
    P.numFrames                 = 10000;
    P.batchSize                 = 2000;
    P.downsamplingFactor        = 1;                    % Flag for displaying roi labels
    P.finalization              = 'Add rois to current Roi Group';
    P.finalization_             = {'Add rois to current Roi Group', 'Add rois to new Roi Group', 'Add rois to new window'};
    P.run                       = false;
    P.run_                      = struct('type', 'button', 'args', {{'String', 'Run Autosegmentation', 'FontWeight', 'bold', 'ForegroundColor', [0.1840    0.7037    0.4863]}});
    
    % - - - - Specify validation/assertion test for each parameter - - - -
    
    V                           = struct();
%     V.showNeuropilMask          = @(x) assert( islogical(x) && isscalar(x), ...
%                                     'Value must be a logical scalar' );
%     V.showLabels                = @(x) assert( islogical(x) && isscalar(x), ...
%                                     'Value must be a logical scalar' );
                                
end
