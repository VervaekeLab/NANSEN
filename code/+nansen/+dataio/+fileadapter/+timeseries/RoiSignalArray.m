classdef RoiSignalArray < nansen.dataio.FileAdapter
%ROISIGNALS Summary of this class goes here
%   Detailed explanation goes here

% Todo: Channels....
% Todo: Use timetable 


% methods:
%   writeFromTimeseries
%   writeFromArray
%   writeFromTimeTable?


%   SYNTAX:
%       import nansen.dataio.fileadapter.timeseries.*
%       roiSignalFileAdapter = RoiSignalArray(filename)
%
%       roiSignalFileAdapter.save(data, variableName) saves the roi signal
%       array from the variable data using the name specified in
%       variableName. data is an array with size numSamples x numRois.
%
%   EXAMPLE:
%       
%       filename = 'roi_signal_array.mat'
%       data = rand(100, 8);
%       
%       % Create file adapter
%       roiSignalFileAdapter = nansen.dataio.fileadapter.timeseries.RoiSignalArray(filepath, 'writable');
%       
%       % Save roi signal array.
%       roiSignalFileAdapter.save(dffArray, 'dff')
%       roiSignalFileAdapter.setMetadata('start_time_num', now)
%       roiSignalFileAdapter.setMetadata('sampling_rate', 10)

    properties (Constant)
        DataType = 'RoiSignalArray'
        Description = 'This file contains extracted and processed roi signals';
    end
    
    properties 
        OutputFormat = 'timetable' % timetable, timeseries, array
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'mat'}
    end
    
    methods (Static, Access = protected)
        
        function S = getDefaultMetadata()
        %getDefaultMetadata Get default metadata for class
            S = struct();
            S.VariableNames = {''};
            S.NumSamples = 0;
            S.NumRois = 0;
            S.StartTimeNum = nan;
            S.StartTimeStr = '';
            S.SampleRate = 1;
            S.TimeUnits = 'seconds';
        end
        
    end
    
    methods (Access = protected)
        
        function roiSignalArray = readData(obj, varargin)
        %readData Read data and return as a time series collection
            
            metaS = obj.Metadata;
            dataS = load(obj.Filename, varargin{:});
            
            varNames = fieldnames(dataS);
            
            if isempty(varNames)
                error('No variables were loaded for file "%s"', obj.Name)
            end

            switch obj.OutputFormat
                case 'timetable'
                    roiSignalArray = obj.convertToTimetable(dataS, metaS);
                case 'timeseries'
                    roiSignalArray = obj.convertToTimeseries(dataS, metaS);
            end

        end
        
        function writeData(obj, data, varargin)
        %writeData
            
            if isempty(varargin)
                error('Variable name is required to save roi signal array')
            else
                varName = varargin{1};
                varargin = varargin(2:end);
                assert(isa(varName, 'char'), 'Variable name must be a character vector')
            end
            
            dataS = struct;
            dataS.(varName) = data;
            
            metaS = obj.Metadata;
            
            if isfile(obj.Filename)
                obj.assertValidSize(data, metaS.Data, varName)
                save(obj.Filename, '-struct', 'dataS', '-append')
                metaS.Data.VariableNames = unique(cat(2, metaS.Data.VariableNames, varName), 'stable');
            else
                save(obj.Filename, '-struct', 'dataS')
                metaS.Data.VariableNames = {varName};
                metaS.Data.NumSamples = size(data, 1);
                metaS.Data.NumRois = size(data, 2);
            end
            
            obj.writeMetadata(metaS)
            
        end

    end
    
    methods (Access = private)
        
        function data = convertToTimetable(obj, dataS, metaS)
        %convertToTimetable Convert loaded data to timetable    
            samplingRate =  metaS.Data.SampleRate;
            
            vars = struct2cell(dataS);
            
            data = timetable(vars{:},'SampleRate', samplingRate, ...
                'VariableNames', fieldnames(dataS));

        end
        
        function data = convertToTimeseries(obj, dataS, metaS)
        %convertToTimeseries Convert data to a time series or array of timeseries
            
            varNames = fieldnames(dataS);
            
            % Create time vector: % Todo: method...
            timevals = (0:metaS.NumSamples-1) ./ metaS.SampleRate;
            
            % Create timeseries for each of the variables.
            tsCellArray = cell(1, numel(varNames));
            for i = 1:numel(varNames)
                
                name = varNames{i};
                datavals = dataS.(name);
                
                ts = timeseries(datavals, timevals, 'Name', name);
                tsCellArray{i} = ts;
            end
            
            if numel(tsCellArray) > 1
                data = tscollection(tsCellArray, 'Name', 'Roi Signal Array');
            else
                data = tsCellArray{1};
            end
            
        end
        
        function [metaS, dataS] = convertFromTimetable(obj, timetableObj)
            % Todo...
        end
        
        function [metaS, dataS] = convertFromTimeseries(obj, timeseriesObj)
            % Todo...
        end
        
        function varNames = getDataVariableNames(obj, loadedData, varargin)
        %getDataVariableNames Get variable names from args or loaded data
            if ~isempty(varargin)
                varNames = varargin;
            else
                varNames = fieldnames(loadedData);
            end
        end
    end
    
    methods (Access = protected)
        
    end
    
    methods (Access = private, Static)
        
        function assertValidSize(data, metadata, varName)
            message = sprintf('Can not add "%s" to roi signal array because the array size does not match existing variables in file', varName);
            
            assert( size(data, 1) == metadata.NumSamples, message )
            assert( size(data, 2) == metadata.NumRois, message )
        end

    end
    
end

