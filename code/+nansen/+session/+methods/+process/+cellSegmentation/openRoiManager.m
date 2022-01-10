classdef openRoiManager < nansen.session.SessionMethod
    
    properties (Constant) % SessionMethod attributes
        MethodName = 'Open Roimanager'
        IsManual = false        % Does method require manual supervision
        IsQueueable = false      % Can method be added to a queue
        BatchMode = 'serial' % Move to data method?
        OptionsManager = nansen.OptionsManager(mfilename('class'))
    end
    
    methods (Static)
        function S = getDefaultOptions()
            S = struct();
        end
    end
    
    methods
        
        function obj = openRoiManager(varargin)

            % Call the SessionTask constructor last to make sure the
            % session's data I/O model is used.
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargin; return; end
            
            obj.checkArgsForOptions(varargin{:});
                        
            sessionData = nansen.session.SessionData( varargin{1} );
            sessionData.updateDataVariables()
            
            imageStack = sessionData.TwoPhotonSeries_Corrected;
            
            nansen.roimanager(imageStack)
            
        end
        
    end
end