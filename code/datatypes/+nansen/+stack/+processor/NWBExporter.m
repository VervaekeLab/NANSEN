classdef NWBExporter < nansen.stack.ImageStackProcessor

    % Todo:
    %   [ ] Device
    %   [ ] ImagingPlane
    %   [ ] OpticalChannel


    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'NWB ImageStack Exporter'
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class'))
    end

    properties (Constant)
        Dependency = 'NWB'
    end

    properties (Access = private)       
        PathName % Path name for NWB file
        NwbObject % Object representing NWB file
        DataPipeObject
    end

    methods (Static)
    
        function S = getDefaultOptions()
            % Get default options for the deep interpolation denoiser.
            S.NWBExporter.NWBFilePath = '';
            S.NWBExporter.CompressionLevel = 3;
            S.NWBExporter.ChunkSize = nan;
            S.NWBExporter.LongDimension = 'T';
            S.NWBExporter.LongDimension_ = {'T', 'Z'};
            S.NWBExporter.GroupName = 'acquisition';
            S.NWBExporter.GroupName_ = {'acquisition', 'processing'};
            S.NWBExporter.NeuroDataType = 'TwoPhotonSeries';
            S.NWBExporter.NeuroDataType_ = {'TwoPhotonSeries', 'OnePhotonSeries', 'ImageSeries'};
        end

    end

    methods % Constructor
        
        function obj = NWBExporter(sourceStack, varargin)

            obj@nansen.stack.ImageStackProcessor(sourceStack, varargin{:})
            
            if ~nargout
                obj.runMethod()
                clear obj
            end
        end

    end


    methods (Access = protected) % Overide ImageStackProcessor methods

        function onInitialization(obj)
        %onInitialization Custom code to run on initialization.
            obj.initializeNWBFile()
            % Todo: Check if datapipe/dataset for writing already exists?
            obj.initializeDataPipe()
        end
    end

    methods (Access = protected) % Method for processing each part

        function [Y, results] = processPart(obj, Y, ~)
            obj.DataPipeObject.append(Y); % append the loaded data
            results = struct.empty;
        end

    end

    methods (Access = private)

        function initializeNWBFile(obj)          
            
            if isfile(oj.PathName)
                obj.NWBObject = nwbRead(obj.PathName);
            else
                obj.NWBObject = NwbFile();
            end
        end

        function initializeDataPipe(obj)

            obj.Options.NWBExporter.CompressionLevel = 3;
            obj.Options.NWBExporter.ChunkSize = nan;
            obj.Options.NWBExporter.LongDimension = 'T';

            % Resolve axis based on the selected dimension name...

            % Skip first dimension for max Size?

            % Compress the data
            obj.DataPipeObject = types.untyped.DataPipe(...
                'maxSize', size(obj.SourceStack.Data), ...
                'dataType', obj.SourceStack.DataType, ...
                'axis', 1);

           
            % Todo: Get data object type from inputs...

            %Set the compressed data as a time series
            fdataNWB = types.core.TimeSeries( ...
                'data', obj.DataPipeObject); %, ...
                %'data_unit', 'mV'); % Todo: add data unit?
            
            nwb.acquisition.set('time_series', fdataNWB);

            if ~isfile(oj.PathName)
                nwbExport(obj.NWBObject, obj.PathName);
            end
        end
        
    end
end