classdef Quicky < nansen.session.SessionMethod & nansen.wrapper.quicky.Processor
%Detect ROIs automatically with Quicky.
%
%Use this when:
%- You want a fast automated segmentation pass on `TwoPhotonSeries_Corrected`.
%- Your data are similar to the Thy1-GCaMP6s recordings this method was
%  developed around in the Vervaeke Lab.
%
%What happens:
%- NANSEN loads the motion-corrected stack and opens it as the source stack
%  for the Quicky wrapper.
%- Quicky is run through the NANSEN ROI segmentation pipeline, including
%  chunking, result merging, ROI-image computation, and ROI-statistics
%  computation.
%
%Outputs:
%- `roiArrayQuickyAuto`: automatically detected ROIs.
%- `QuickyOptions` and intermediate Quicky result files are saved for
%  provenance and restart support.
%
%Limitations:
%- Quicky is tuned for a specific data style and may not generalize as well
%  to other preparations, indicators, or imaging systems.
    
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
