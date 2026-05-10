classdef flowreg < nansen.session.SessionMethod & nansen.wrapper.flowreg.Processor
%Motion-correct the raw two-photon recording with FlowRegistration.
%
%Use this when:
%- You want non-rigid motion correction using the FlowRegistration toolbox.
%- You need motion-corrected data plus diagnostic projections and movement
%  statistics saved back into the session.
%
%What happens:
%- NANSEN loads `TwoPhotonSeries_Original` and enables stack preprocessing.
%- FlowRegistration estimates frame shifts and writes the corrected stack.
%- Reference images, projections, and correction statistics are generated
%  by the shared motion-correction pipeline.
%
%Outputs:
%- `TwoPhotonSeries_Corrected`: motion-corrected image stack.
%- `FlowregOptions` and `FlowregShifts`: method-specific settings and
%  frame shifts.
%- Motion-correction QC outputs such as `FovAverageProjection`,
%  `FovMaximumProjection`, and `MotionCorrectionStats`.
%
%Reference:
%- https://github.com/phflot/flow_registration

    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial' % Move to data method?
    end
    
    methods
        
        function obj = flowreg(varargin)
            
            % Dont want this to be in charge, use session task instead.
            obj@nansen.wrapper.flowreg.Processor()
            
            % Call the SessionTask constructor last to make sure the
            % session's data I/O model is used.
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargin; return; end
            
            % Todo: ParseVararginForOptions Move to session method???
            obj.checkArgsForOptions(varargin{:});
                        
            sessionData = nansen.session.SessionData( varargin{1} );
            sessionData.updateDataVariables()
            
            sessionData.TwoPhotonSeries_Original.enablePreprocessing()

            obj.openSourceStack(sessionData.TwoPhotonSeries_Original)
            
            if ~nargout % how to generalize this???
                obj.runMethod()
                clear obj
            end
        end
    end
end
