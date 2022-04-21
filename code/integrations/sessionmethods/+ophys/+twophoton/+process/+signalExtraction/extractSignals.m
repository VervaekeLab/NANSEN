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
                clear obj
            end
            
        end
        
    end
    
    methods
        
        function runMethod(obj)
            
            sessionData = nansen.session.SessionData(obj.SessionObjects);
            sessionData.updateDataVariables()
            
            imageStack = sessionData.TwoPhotonSeries_Corrected;
            roiArray = sessionData.RoiArray; 
            
            extractF = @nansen.twophoton.roisignals.extractF;
            [signalArray, P] = extractF(imageStack, roiArray, 'verbose', true, obj.Parameters);
            
            % Todo: Save results...
            obj.saveData('RoiSignals_MeanF', squeeze(signalArray(:, 1, :)) )
            obj.saveData('RoiSignals_NeuropilF', squeeze(signalArray(:, 2:end, :)) )
            
            
            obj.saveData('OptionsSignalExtraction', P, ...
                'Subfolder', 'roisignals', 'IsInternal', true)
            
            % Inherit metadata from image stack
            fileAdapter = obj.SessionObjects.getFileAdapter('RoiSignals_MeanF');
            fileAdapter.setMetadata('SampleRate', imageStack.getSampleRate(), 'Data')
            %fileAdapter.setMetadata('StartTimeNum', imageStack.getStartTime('number'), 'Data')
            %fileAdapter.setMetadata('StartTimeStr', imageStack.getStartTime('string'), 'Data')
        end
        
    end

end