classdef suite2p < nansen.session.SessionMethod & nansen.wrapper.suite2p.Processor
%Detect ROIs automatically with suite2p.
%
%Use this when:
%- You want to run suite2p ROI detection on `TwoPhotonSeries_Corrected`
%  from inside the NANSEN session workflow.
%- You want suite2p results saved back into the session data model rather
%  than managed only in an external suite2p output folder.
%
%What happens:
%- NANSEN loads the motion-corrected stack and opens it as the source stack
%  for the suite2p wrapper.
%- suite2p is run through the NANSEN ROI segmentation pipeline, including
%  chunking, component merging, ROI-image computation, and ROI-statistics
%  computation.
%
%Outputs:
%- `roiArraySuite2pAuto`: automatically detected ROIs.
%- `Suite2pOptions`, `Suite2pResultsTemp`, and `Suite2pResultsFinal` are
%  saved as method outputs for provenance and restart support.

    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial' % Move to data method?
    end

    methods

        function obj = suite2p(varargin)

            % Dont want this to be in charge, use session task/method instead.
            obj@nansen.wrapper.suite2p.Processor()

            % Call the SessionTask constructor last to make sure the
            % session's data I/O model is used.
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargin; return; end

            % Todo: ParseVararginForOptions Move to session method???
            obj.checkArgsForOptions(varargin{:});

            obj.SessionObjects.validateVariable('TwoPhotonSeries_Corrected')

            sessionData = nansen.session.SessionData( varargin{1} );
            sessionData.updateDataVariables()

            obj.openSourceStack(sessionData.TwoPhotonSeries_Corrected)

            if ~nargout % how to generalize this???
                obj.runMethod()
                clear obj
            end
        end
    end
end
