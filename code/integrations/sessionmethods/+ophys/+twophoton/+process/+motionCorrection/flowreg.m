classdef flowreg < nansen.session.SessionMethod & nansen.wrapper.flowreg.Processor
%normcorre Summary of this function goes here
%   Detailed explanation goes here
    

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