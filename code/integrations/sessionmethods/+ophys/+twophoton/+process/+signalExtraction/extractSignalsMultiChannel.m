classdef extractSignalsMultiChannel < nansen.session.SessionMethod
%EXTRACTSIGNALS Summary of this function goes here
%   Detailed explanation goes here
%
%   Session method wrapper for SignalExtractor
    
    properties (Constant) % SessionMethod attributes
        MethodName = 'Extract Signals (MultiChannel)'
        BatchMode = 'serial'
        IsManual = false
        IsQueueable = true
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager('nansen.processing.SignalExtractor')
    end
    
    properties (Constant)
        DATA_SUBFOLDER = 'roisignals'       % defined in nansen.DataMethod
        VARIABLE_PREFIX	= 'RoiSignals'      % defined in nansen.DataMethod
    end

    properties 
        RequiredVariables = {'TwoPhotonSeries_Corrected', 'roiArray'}
    end
    
    
    methods (Static)
        function S = getDefaultOptions()
            %S = nansen.twophoton.roisignals.extract.getDefaultParameters();
        end
    end
    
    methods
        
        function obj = extractSignalsMultiChannel(varargin)
            
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
            currentChannels = imageStack.CurrentChannel;
            imageStack.CurrentChannel = 1:imageStack.NumChannels;

            roiArray = sessionData.RoiArray;
            
            nansen.processing.SignalExtractor(imageStack, obj.Options, roiArray, obj.SessionObjects)
            
            % Reset channels
            imageStack.CurrentChannel = currentChannels;
        end
        
    end

    methods
        function printTask(obj, varargin)
            fprintf(varargin{:})
        end
    end

end