classdef normcorre < nansen.session.SessionMethod & nansen.wrapper.normcorre.Processor
%NORMCORRE Runs motion correction using NORMCORRE on TwoPhoton_Original
%   Matlab routines for online non-rigid motion correction of calcium
%   imaging data.
%
%   For details, check out NORMCORRE on GitHub: https://github.com/flatironinstitute/NoRMCorre
    
    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial' % Move to data method?
    end
    
    methods
        
        function obj = normcorre(varargin)
            
            % Dont want this to be in charge, use session task instead.
            obj@nansen.wrapper.normcorre.Processor()
            
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
