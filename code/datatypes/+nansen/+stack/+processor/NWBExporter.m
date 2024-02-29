classdef NWBExporter < nansen.stack.ImageStackProcessor

    % Note: This is developed for two photon image stacks.
    %
    % 
    % Todo:
    %   [ ] Generalize
    %   [ ] Consider the use of append when adding data. What if the method
    %       is resumed from a previous run?
    %   [ ] Add more metadata
    %   [ ] Reconsider using the CorrectedImageStack type.
    %    -  For Motion Correction (Defer this...):
    %       [ ] Link to original file if possible
    %       [ ] Way to insert shifts / translations
    %       [ ] Should imaging plane be shared among original and
    %           corrected?
    %   [V] Create Device
    %   [V] Create ImagingPlane
    %   [V] Create OpticalChannel
    %   [V] One nwb dataset per plane and channel



    properties (Constant) % Attributes inherited from nansen.DataMethod
        MethodName = 'NWB ImageStack Exporter'
        IsManual = false        % Does method require manual supervision?
        IsQueueable = true      % Can method be added to a queue?
        OptionsManager nansen.manage.OptionsManager = ...
            nansen.OptionsManager(mfilename('class'))
    end

    properties (Constant)
        DATA_SUBFOLDER = ""	% defined in nansen.processing.DataMethod
        VARIABLE_PREFIX	= "" % defined in nansen.processing.DataMethod
    end

    properties (Constant, Access = private)
        TYPE_PACKAGE_PREFIX = "matnwb.types.core"
    end

    properties
        SemanticDataType (1,1) string ...
            {mustBeMember(SemanticDataType, {'Acquired', 'MotionCorrected'})} = "Acquired"
    end

    properties (Constant)
        Dependency = 'NWB'
    end

    properties (Access = private)       
        PathName % Path name for NWB file
        NWBObject % Object representing NWB file
        Device
        ImagingPlanes cell % Cell array (numPlanes x numChannels) of objects.
        DataPipeObject cell % Cell array (numPlanes x numChannels) of objects.
    
        %Device
        %OpticalChannel
        %ImagingPlane
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
            S.NWBExporter.NeuroDataType_ = {'TwoPhotonSeries', 'OnePhotonSeries', 'ImageSeries'}; % Todo...
        
            S.NWBMetadata.DeviceDescription = '';
            S.NWBMetadata.DeviceManufacturer = '';
            S.NWBMetadata.ExcitationWavelength = [];
            S.NWBMetadata.IndicatorNames = ''; % List of strings.
            S.NWBMetadata.RecordingLocation = '';

            className = mfilename('class');
            superOptions = nansen.mixin.HasOptions.getSuperClassOptions(className);
            S = nansen.mixin.HasOptions.combineOptions(S, superOptions{:});
        end

    end

    methods % Constructor
        
        function obj = NWBExporter(sourceStack, varargin)
            
            % Todo:
            % assert(isInstalled('matnwb'))

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

            if isempty(obj.Options.NWBExporter.NWBFilePath)
                sourceFilePath = obj.SourceStack.FileName;
                [folder, fileName, ~] = fileparts(sourceFilePath);
                obj.PathName = fullfile(folder, [fileName, '.nwb']);
            else
                obj.PathName = obj.Options.NWBExporter.NWBFilePath;
            end

            if strcmp(obj.Options.NWBExporter.GroupName, 'processing')
                obj.SemanticDataType = "MotionCorrected";
            end

            wasInitialized = obj.initializeNWBFile();

            obj.initializeGroups() % Device / opticalchannel / imagingplanes

            % Todo: Check if datapipe/dataset for writing already exists
            obj.initializeDataPipes()

            %if wasInitialized
            nwbExport(obj.NWBObject, obj.PathName);
            %end
        end
    end

    methods (Access = protected) % Method for processing each part

        function [Y, results] = processPart(obj, Y, ~)

            % Todo: Use indexing into data pipe object?? This would be
            % necessary if the operation is canceled and restarted.

            obj.DataPipeObject{obj.CurrentPlane, obj.CurrentChannel}.append(Y); % append the loaded data
            results = struct.empty;
        end

    end

    methods (Access = private)

        function wasInitialized = initializeNWBFile(obj)
            if isfile(obj.PathName)
                obj.NWBObject = nwbRead(obj.PathName);
                wasInitialized = false;
            else
                obj.NWBObject = NwbFile();
                wasInitialized = true;
            end
        end

        function initializeGroups(obj)
            % Create a device
            obj.Device = obj.createDevice();
            obj.NWBObject.general_devices.set('two_photon_microscope', obj.Device);

            opticalChannels = obj.createOpticalChannels();

            obj.StackIterator.reset()
            for i = 1:obj.StackIterator.NumIterations
                [iZ, iC] = obj.StackIterator.next();
                
                % Create imaging planes.
                imagingPlane = matnwb.types.core.ImagingPlane( ...
                    'description', 'n/a', ...
                    'device', matnwb.types.untyped.SoftLink(obj.Device), ...
                    'excitation_lambda', obj.Options.NWBMetadata.ExcitationWavelength, ...
                    'imaging_rate', obj.SourceStack.MetaData.SampleRate, ...
                    'indicator', obj.Options.NWBMetadata.IndicatorNames, ...
                    'location', 'n/a');
                
                % Todo: This should refer to channel index of microscope,
                % not channel index of image stack.
                channelName = sprintf('channel%d', iC);

                imagingPlaneName = sprintf('imaging_plane%d_%s', iZ, channelName);

                % Add the optical channel to the imaging plane
                imagingPlane.opticalchannel.set(channelName, opticalChannels{iC});

                % Add the imaging plane to the nwb object
                obj.NWBObject.general_optophysiology.set(imagingPlaneName, imagingPlane);

                obj.ImagingPlanes{iZ, iC} = imagingPlane;
            end
        end

        function initializeDataPipes(obj)

            %compressionLevel = obj.Options.NWBExporter.CompressionLevel;
            %chunkSize = obj.Options.NWBExporter.ChunkSize;
            %obj.Options.NWBExporter.LongDimension = 'T';

            dataSize = [...
                obj.SourceStack.ImageHeight, ...
                obj.SourceStack.ImageWidth, ...
                obj.SourceStack.NumTimepoints ];

            obj.DataPipeObject = cell(obj.SourceStack.NumPlanes, obj.SourceStack.NumChannels);

            obj.StackIterator.reset()
            for i = 1:obj.StackIterator.NumIterations
                [iZ, iC] = obj.StackIterator.next();

                % Compress the data
                obj.DataPipeObject{iZ, iC} = matnwb.types.untyped.DataPipe(...
                    'maxSize', dataSize, ...
                    'dataType', obj.SourceStack.DataType, ...
                    'axis', 3);

                twoPhotonSeries = matnwb.types.core.TwoPhotonSeries( ...
                    'imaging_plane', matnwb.types.untyped.SoftLink(obj.ImagingPlanes{iZ, iC}), ...
                    'starting_time', 0.0, ...
                    'starting_time_rate', obj.SourceStack.MetaData.SampleRate, ...
                    'data', obj.DataPipeObject{iZ, iC}, ...
                    'data_unit', 'lumens');
                
                name = sprintf('two_photon_data_plane%d_channel%d', iZ, iC);
                obj.addTwoPhotonSeriesToNwb(name, twoPhotonSeries)
            end
        end
        
        function device = createDevice(obj)
            device = matnwb.types.core.Device();

            if ~isempty(obj.Options.NWBMetadata.DeviceDescription)
                device.description = obj.Options.NWBMetadata.DeviceDescription;
            else
                device.description = 'A two-photon microscope';
            end

            if ~isempty(obj.Options.NWBMetadata.DeviceManufacturer)
                device.manufacturer = obj.Options.NWBMetadata.DeviceManufacturer;
            else
                device.manufacturer = 'N/A'; % todo: obj.resolveManufacturer();
            end
        end

        function opticalChannels = createOpticalChannels(obj)

            numChannels = obj.SourceStack.NumChannels;
            opticalChannels = cell(1, numChannels);
            
            for i = 1:numChannels
                opticalChannels{i} = matnwb.types.core.OpticalChannel();
            end

            % Todo: % Should be present on imagestack metadata.
            % description
            % emission_lambda
        end
        
        function addTwoPhotonSeriesToNwb(obj, name, twoPhotonSeries)
            
            if strcmp(obj.SemanticDataType, 'Acquired')
            % Add the two photon series to the acquisiton group.
                name = sprintf('original_%s', name);
                obj.NWBObject.acquisition.set(name, twoPhotonSeries);

            elseif strcmp(obj.SemanticDataType, 'MotionCorrected')
            % Add the two photon series to a correctedImageStack and append
            % it to the MotionCorrectionGroup.
                motionCorrection = obj.getMotionCorrectionGroup();
            
                rawTwoPhotonSeries = obj.getOriginalTwoPhotonSeriesLink(name);

                xyTimeseries = matnwb.types.core.TimeSeries( );

                % Todo: Add shifts and link to original?
                correctedImageStack = matnwb.types.core.CorrectedImageStack(...
                    'corrected', twoPhotonSeries, ...
                    'original', matnwb.types.untyped.SoftLink(rawTwoPhotonSeries), ...
                    'xy_translation', xyTimeseries );
            
                name = sprintf('corrected_%s', name);
                motionCorrection.correctedimagestack.set(name, correctedImageStack);
            end
        end

        function twoPhotonSeries = getOriginalTwoPhotonSeriesLink(obj, name)

            optical_channel = matnwb.types.core.OpticalChannel();
            
            imaging_plane = matnwb.types.core.ImagingPlane(...
                'device', matnwb.types.untyped.SoftLink(obj.Device), ...
                'opticalchannel', optical_channel);

            twoPhotonSeries = matnwb.types.core.TwoPhotonSeries(...
                'dimension', [100, 100], ...
                'external_file', 'missing', ...
                'external_file_starting_frame', 0, ...
                'imaging_plane', matnwb.types.untyped.SoftLink(imaging_plane), ...
                'format', 'external', ...
                'starting_time', 0.0, ...
                'starting_time_rate', 1.0 ...
                );
            
            name = sprintf('missing_%s', name);
            obj.NWBObject.general_optophysiology.set(name, imaging_plane);

            obj.NWBObject.acquisition.set(name, twoPhotonSeries);
        end

        function motionCorrection = getMotionCorrectionGroup(obj)
        % getMotionCorrection - Get MotionCorrection group from the NWB

            % The MotionCorrection group should be located in an ophys
            % processing module. Retrieve it, or create it if it does not
            % exist.

            try % Todo: test for existence
                ophysModule = obj.NWBObject.processing.get('ophys');
            catch
                ophysModule = matnwb.types.core.ProcessingModule( ...
                'description',  'contains optical physiology data');
                obj.NWBObject.processing.set('ophys', ophysModule);
            end

            try % Todo: test for existence
                motionCorrection = ophysModule.nwbdatainterface.get('MotionCorrection');
            catch
                motionCorrection = matnwb.types.core.MotionCorrection();
                ophysModule.nwbdatainterface.set('MotionCorrection', motionCorrection);
            end
        end
    end
end