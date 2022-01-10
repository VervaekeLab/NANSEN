classdef normcorre < nansen.session.SessionMethod & nansen.module.normcorre.Processor
%normcorre Summary of this function goes here
%   Detailed explanation goes here
    
    properties (Constant) % SessionMethod attributes
        BatchMode = 'serial' % Move to data method?
    end
    
    methods
        
        function obj = normcorre(varargin)
            
            % Dont want this to be in charge, use session task instead.
            obj@nansen.module.normcorre.Processor()
            
            % Call the SessionTask constructor last to make sure the
            % session's data I/O model is used.
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargin; return; end
            
            % Todo: ParseVararginForOptions Move to session method???
            obj.checkArgsForOptions(varargin{:});
                        
            sessionData = nansen.session.SessionData( varargin{1} );
            sessionData.updateDataVariables()
            
            obj.openSourceStack(sessionData.TwoPhotonSeries_Original)
            
            if ~nargout % how to generalize this???
                obj.runMethod()
                clear obj
            end 
            
        end
        
    end

end