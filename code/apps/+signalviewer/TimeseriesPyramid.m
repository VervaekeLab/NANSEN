classdef TimeseriesPyramid < handle
%TimeseriesPyramid Pyramidal multilevel downsampled timeseries data
%
%   This class is used for dynamically adjusting the number of data points 
%   that are plotted  based on the screen resolution and the x-axis limits 
%   in the signalviewer app.

%   Note: Only supports timetable input.

    % Todo:
    %   [ ] Get data from specific variables in getData method
    %   [ ] Implement downsampleStepFactor as a preference/setting
    %   [ ] Accept timeseries and timeseries colletions as inputs...
    %   [ ] Combine similarities from HighResolutionImage into a superclass?
    
    properties % Settings...
        DataPointPerPixel = 1;
        % DownsampleStepFactor
    end
    
    properties
        DoRescaleData = true;
        DoBaselineSubtraction = true;
    end
    
    properties (SetAccess = protected) % Data scale constants
        Amplitude % numeric or struct (per variable...)
        %Baseline
        
        NumSeries double    % Number of timeseries
        NumSamples double   % Vector with number of samples per downsampling level
    end
    
    properties (SetAccess = private)
        xData cell          % Cell array of xdata for each downsampling level
        TData cell          % Cell array with timeseries data for each downsampling level
        
        CurrentLevel        % The current downsampling level
    end
    
    properties (Access = private)
        DownsamplingFactors % Vector of downsampling factors per level
        ScreenResolution    % Screen resolution
    end
    
    
    methods % Constructor
        
        function obj = TimeseriesPyramid(timeTableObj, dpPerPixel)
        %TimeseriesPyramid Create object with multilevel downsampling
        
            if nargin == 2
                obj.DataPointPerPixel = dpPerPixel;
            end
            
% %             if obj.DoBaselineSubtraction || obj.DoRescaleData
% %                 timeTableObj = obj.preprocessData(timeTableObj);
% %             end
            
            obj.assignScreenResolution()
            obj.calculateDataLevels( timeTableObj )

        end
        
    end
    
    methods
    
        function [xData, tData] = getData(obj, xLim, varName)
        %getData Get data given a set of x limits.
        %
        %   [xData, tData] = getData(obj, xLim) returns xdata and tdata for
        %   a given set of xlimits.
        %
        %   % Todo: get data from specific variables
        
            level = obj.getLevel(xLim);
            
            xDataFull = obj.xData{level};
            tDataFull = obj.TData{level};
            
            
            ind = xDataFull >= xLim(1) & xDataFull <= xLim(2);
            
            xData = xDataFull(ind);
            tData = tDataFull(ind, :);
            
            obj.CurrentLevel = level;
            
        end
        
        function level = getLevel(obj, xLim)
        %getLevel Get the downsampling level for given x limits.
        %
        %   level = getLevel(obj, xLim) returns a scalar integer
        %   representing the downsampling level which is ideal for the
        %   given x limits. The ideal level is determined based on the
        %   screen resolution and the datapoints per pixel preference.
        
            numSamplesRequested = range(xLim);
            numSamplesDisplay = obj.ScreenResolution(1) * obj.DataPointPerPixel;
            
            dsFactor = numSamplesRequested / numSamplesDisplay;
            [~, level] = min(abs(obj.DownsamplingFactors - dsFactor));
            
        end
        
    end
    
    methods (Access = protected)
        
        function data = preprocessData(obj, data)
            
            baselinePrctile = 25;
            peakPrctile = 99.9;
            
            numVariables = size(data, 2);
            variableNames = data.Properties.VariableNames;
            
            for i = 1:numVariables
                thisVar = variableNames{i};
                
                yData = data.(thisVar);
                
                if obj.DoBaselineSubtraction 
                    baseline = prctile(yData, baselinePrctile, 1);
                    yData = yData - baseline;
                end
                
                if obj.DoRescaleData
                    peakAmplitude = prctile(yData(:), peakPrctile);
                    yData = yData ./ peakAmplitude;
                end
                
                data.(thisVar) = yData;
                obj.Amplitude.(thisVar) = peakAmplitude;
                
            end
        end
        
    end
    
    methods (Access = private)
        
        function assignScreenResolution(obj)
            screenSize = get(0, 'ScreenSize');
            obj.ScreenResolution = screenSize(3:4);
        end
        
        function calculateDataLevels(obj, timeTableObj)
        % Calculate downsampled versions of data at multiple levels.
            
            % Todo: implement this as a preference/setting
            downsamplingStepFactor = 2;
        
            numSamplesMin =  obj.ScreenResolution(1) .* obj.DataPointPerPixel;
            numSamplesMax = size(timeTableObj, 1);
            
            dsFactors = obj.getDownsamplingFactors(numSamplesMax, ...
                numSamplesMin, downsamplingStepFactor);
            obj.DownsamplingFactors = [1, dsFactors];
            
            sampleRateOrig = timeTableObj.Properties.SampleRate;
            sampleRateTemp = sampleRateOrig;
            
            numLevels = numel(dsFactors);
            [obj.xData, obj.TData] = deal( cell(1, numLevels+1) );

            obj.TData{1} = timeTableObj;
            obj.xData{1} = 1:size(timeTableObj, 1);
            for i = 2:numLevels+1
                obj.TData{i} = timetable.range(obj.TData{i-1},downsamplingStepFactor);
                %obj.TData{i} = timetable.range(obj.TData{1},power(downsamplingStepFactor,i-1));
                %sampleRateTemp = sampleRateTemp ./ downsamplingStepFactor;
                %obj.TData{i} = retime(obj.TData{i-1}, 'regular', 'linear', ...
                %    'SampleRate', sampleRateTemp);
                %obj.xData{i} = seconds(obj.TData{i}.Time);
                obj.xData{i} = linspace(1, numSamplesMax, size(obj.TData{i}, 1));
                
            end
            
            obj.NumSamples = cellfun(@numel, obj.xData);
            
        end

        function onDataPointPerPixelChanged(obj)
            if ~isempty(obj.TData)
                obj.calculateDataLevels( obj.TData{1} )
            end
        end
        
    end
    
    methods 
        function set.DataPointPerPixel(obj, newValue)
            obj.DataPointPerPixel = newValue;
            obj.onDataPointPerPixelChanged()
        end
    end
    
    methods (Static)
        
        function tf = useDownsampling(numSamples, dpPerPixel)
        %useDownsampling Determine if downsampling should be used
        %
        %   tf = useDownsampling(numSamples, dpPerPixel) returns 1 (true)
        %   if downsampling should be used for data with given number of 
        %   samples (numSamples) for the specified number of datapoints 
        %   per pixel (dpPerPixel). Otherwise returns false.
            
            screenSize = get(0, 'ScreenSize');
            obj.ScreenResolution = screenSize(3:4);
            
            tf =  obj.ScreenResolution(1) .* dpPerPixel < numSamples;
            
        end
    end
    
    methods (Static, Access = private)
        
        function dsFactors = getDownsamplingFactors(numSamplesMax, numSamplesMin, downsamplingStepFactor)
            
            numSamples = numSamplesMax;
            finished = false;
            count = 0;
            
            dsFactors = [];
            
            while ~finished
                count = count+1;
                numSamples = numSamples/downsamplingStepFactor;

                dsFactors(end+1) = round(numSamplesMax/numSamples);
                
                if numSamples < numSamplesMin
                    finished = true;
                end
            end
            
        end
        
    end
    
end


% % %         function calculateDataLevels2(obj, timeTableObj)
% % %             % Old version, always downsample from original. Slower, but
% % %             % does not look different
% % %             sampleRateOrig = timeTableObj.Properties.SampleRate;
% % % 
% % %             numLevels = numel(dsFactors);
% % %             [xData2, TData2] = deal( cell(1, numLevels) );
% % %             tic
% % %             for i = 1:numLevels
% % %                 
% % %                 sampleRateTemp = sampleRateOrig ./ dsFactors(i);
% % %                 TData2{i} = retime(timeTable, 'regular', 'linear', ...
% % %                     'SampleRate', sampleRateTemp);
% % %                 xData2{i} = linspace(1, numSamplesMax, size(TData2{i}, 1));
% % %                 
% % %             end
% % %             toc
% % %         
% % %         end