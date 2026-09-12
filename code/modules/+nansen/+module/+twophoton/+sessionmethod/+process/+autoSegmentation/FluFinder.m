classdef FluFinder < nansen.session.SessionMethod & nansen.module.twophoton.autosegmentation.flufinder.Processor
%Detect ROIs automatically with FluFinder.
%
%Use this when:
%- You want a fast automated segmentation pass on `TwoPhotonSeries_Corrected`.
%- Your data are similar to the Thy1-GCaMP6s recordings this method was
%  developed around in the Vervaeke Lab.
%
%What happens:
%- NANSEN loads the motion-corrected stack and opens it as the source stack
%  for the FluFinder processor.
%- FluFinder is run through the NANSEN ROI segmentation pipeline, including
%  chunking, result merging, ROI-image computation, and ROI-statistics
%  computation.
%
%Outputs:
%- `roiArrayQuickyAuto`: automatically detected ROIs.
%- `QuickyOptions` and intermediate result files are saved for provenance
%  and restart support.
%
%Limitations:
%- FluFinder is tuned for a specific data style and may not generalize as
%  well to other preparations, indicators, or imaging systems.
%
%Note: this method was previously named Quicky. `Quicky` remains available
%as an alias so that stored pipelines and catalogs keep resolving.

    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial' % Move to data method?
    end

    methods

        function obj = FluFinder(varargin)

            % Dont want this to be in charge, use session task/method instead.
            obj@nansen.module.twophoton.autosegmentation.flufinder.Processor()

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
