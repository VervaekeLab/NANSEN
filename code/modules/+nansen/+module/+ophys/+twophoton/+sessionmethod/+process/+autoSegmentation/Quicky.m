classdef Quicky < nansen.session.SessionMethod & nansen.wrapper.quicky.Processor
%QUICKY Runs autosegmentation using QUICKY on TwoPhoton\\_MotionCorrected
%
% Description:
% QUICKY is an auto segmentation algorithm developed for thy-1 GCaMP6s data
% in the VervaekeLab. It is quick, and should produce few false positives,
% but might not generalize well to data from other labs or setups.
%
% Option Presets:
%   - Axons - Will detect smaller axonal bouton like structures
%   - Soma - Optimized for detecting soma-like structure
%   - Soma (Virus) - Optimized for virus expression
%
% Parameters:
%   - RoiDiameter : Diameter in pixels (default : 12)
%   - NumObservationsRequired : Number of times a component should be observed in order to be detected (default : 2).
%   - MaxNumRois : Maximum number of rois to detect (default : 300)
%   - MinimumDiameter : Minimum allowed roi diameter in pixels (default : 4)
%   - MaximumDiameter : Maximum allowed roi diameter in pixels (default : 16)
    
    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial' % Move to data method?
    end
    
    methods
        
        function obj = Quicky(varargin)
            
            % Dont want this to be in charge, use session task/method instead.
            obj@nansen.wrapper.quicky.Processor()
            
            % Call the SessionTask constructor last to make sure the
            % session's data I/O model is used.
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargin; return; end
            
            % Todo: ParseVararginForOptions Move to session method???
            obj.checkArgsForOptions(varargin{:});
                        
            sessionData = nansen.session.SessionData( varargin{1} );
            sessionData.updateDataVariables()
            
            obj.openSourceStack(sessionData.TwoPhotonSeries_Corrected)
            
            if ~nargout
                obj.runMethod()
                clear obj
            end
        end
    end
end
