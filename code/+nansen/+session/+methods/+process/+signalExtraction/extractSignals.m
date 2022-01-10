classdef extractSignals < nansen.session.SessionMethod
%EXTRACTSIGNALS Summary of this function goes here
%   Detailed explanation goes here
    
    properties (Constant) % SessionMethod attributes
        MethodName = 'Extract Signals'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true
        OptionsManager = nansen.OptionsManager(mfilename('class')) % todo...
    end
    
    
    methods (Static)
        function S = getDefaultOptions()
            S = struct();
        end
    end
    
    methods
        
        function obj = extractSignals(varargin)
            
            obj@nansen.session.SessionMethod(varargin{:})

            if ~nargout
                obj.runMethod()
            end
            
        end
        
        
    end
    
    methods
        
        function runMethod(obj)
            
            sessionData = nansen.session.SessionData(obj.sessionObjects);
            sessionData.update()
            
            imageData = sessionData.TwoPhotonSeries_Corrected;
            roiArray = sessionData.RoiArray; %??

            %todo: Options
            
            [signalArray, P] = extractF(imageData, roiArray, varargin)
            
            
            % Todo: Save results...
            
        end
        
    end

    

end