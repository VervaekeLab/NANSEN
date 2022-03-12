classdef extractSignals < nansen.session.SessionMethod
%EXTRACTSIGNALS Summary of this function goes here
%   Detailed explanation goes here
    
    properties (Constant) % SessionMethod attributes
        MethodName = 'Extract Signals'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class')) % todo...
    end
    
    properties 
        RequiredVariables = {'TwoPhotonSeries_Corrected', 'RoiArray'}
    end
    
    
    methods (Static)
        function S = getDefaultOptions()
            S = nansen.twophoton.roisignals.extract.getDefaultParameters();
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
            
            sessionData = nansen.session.SessionData(obj.SessionObjects);
            sessionData.updateDataVariables()
            
            imageData = sessionData.TwoPhotonSeries_Corrected;
            roiArray = sessionData.RoiArray; 
            
            extractF = @nansen.twophoton.roisignals.extractF;
            [signalArray, P] = extractF(imageData, roiArray, obj.Parameters);
            
            
            % Todo: Save results...
            obj.saveData('RoiSignalsMeanF', signalArray, 'Subfolder', 'roisignals')
            obj.saveData('SignalExtractionOptions', P, 'Subfolder', 'roisignals')

        end
        
    end

end