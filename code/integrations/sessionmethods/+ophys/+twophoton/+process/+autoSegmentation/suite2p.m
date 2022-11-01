classdef suite2p < nansen.session.SessionMethod & nansen.wrapper.suite2p.Processor
%EXTRACT Summary of this function goes here
%   Detailed explanation goes here
    
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