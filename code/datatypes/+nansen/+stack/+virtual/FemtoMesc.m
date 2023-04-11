classdef FemtoMesc < nansen.stack.virtual.HDF5
%FemtoMesc Virtual data adapter for a femtonics mesc file

% Todo: 
%   [ ] resolve datasets (multiple recs in one file)
%   [ ]

% H5 Data structure
% Group '/'
%   |- Attributes
%   |- Group 'MSession_0'
%       |- Attributes
%       |- Group 'MSession_0/MUnit_XX'
%           |- Attributes
%           |- Dataset 'Channel_0'
%           |- ...
%           |- Dataset 'Channel_N'
%   |- ...
%   |- Group 'MSession_N'


% Todo:
%     [ ] Save dataset names for each channel. 
%     [ ] Adapt this class so working with channels are very easy.

% Questions
%     - Are channel data stored in individual datasets?
%     - What are the different scan types, i.e time series, zstack...
%     - What is image scale and image offset used for. Why is default
%     - imagescale -1. Is that set by user?
%     - Can we have channel_0 and channel_2?
%       



properties (Constant, Hidden)
    FilenameExpression = ''
    DATA_DIMENSION_ARRANGEMENT = 'CXYZT'
    %FILE_PERMISSION = 'read' % Mesc files should only be read from
end

properties (Access = private, Hidden)
    %H5Info
end

properties (Access = private)
    ImageScale
    ImageOffset
end

methods % Structors
    
    function obj = FemtoMesc(filePath, datasetName, varargin)
    %SciScanRaw Create a virtual data adapter for SciScan raw file  
        % Open folder browser if there are no inputs.
        if nargin < 1; filePath = uigetdir; end
        if nargin < 2; datasetName = ''; end

        obj@nansen.stack.virtual.HDF5(filePath, datasetName, varargin{:})
    end
    
    function delete(obj)
        % close h5
    end
    
end

methods % Implementation of VirtualArray abstract methods
    
    function writeFrameSet(obj, frameIndex, data) %#ok<INUSD>
        error('Writing to a mesc file is not supported')
    end
       
    function writeFrames(obj, frameIndex, data) %#ok<INUSD>
        error('Writing to a mesc file is not supported')
    end
    
end

methods (Access = protected) % Implementation of abstract methods
        
    function assignFilePath(obj, filePath, ~)
    %ASSIGNFILEPATH Assign path to the raw imaging data file.
    
        if isa(filePath, 'cell') && numel(filePath)==1
            filePath = filePath{1};
        else
            error('Something went wrong. Check how to specify filepath in class documentation')
        end
        
        [~, ~, ext] = fileparts(filePath);
        
        assert(strcmp(ext, '.mesc'), 'File must be a .mesc file')

        obj.FilePath = filePath;
        
        obj.h5FileInfo = h5info(obj.FilePath);
        
        if isempty(obj.DatasetName)
            warning('Dataset is not specified, will use the first dataset that looks like an imagestack')
            %datasetNames = obj.listH5Datasets();
        
            if isempty(obj.DatasetName)
                dataSetNameList = obj.listDataSetNames(obj.h5FileInfo);
%                 if numel(dataSetNameList) > 1
%                     dataSetNameList = obj.uiselectDatasetName(dataSetNameList);
%                 end

                obj.DatasetName = dataSetNameList{1};
            end
        end
    end
    
    function getFileInfo(obj)
    %getFileInfo Get file info and assign to properties
        
        if isempty(obj.h5FileInfo)
            obj.h5FileInfo = h5info(obj.FilePath);
        end
        
        obj.DatasetInfoH5 = h5info(obj.FilePath, ['/', obj.DatasetName] );
        dataSize = obj.DatasetInfoH5.Datasets.Dataspace.Size;

        S = obj.getFemtonicsRecordingInfo();
        
        attributeNames = fieldnames(S);

        % Get image/frame size
        obj.MetaData.SizeX = S.XDim;
        obj.MetaData.SizeY = S.YDim;

        obj.MetaData.PhysicalSizeX = double(S.XAxisConversionConversionLinearScale);
        obj.MetaData.PhysicalSizeY = double(S.YAxisConversionConversionLinearScale);


        % Get number of channels
        channelNum = regexp(attributeNames,'Channel_(\d)_Name','tokens');
        channelNum = utility.cell.removeEmptyCells(channelNum);
        channelNum = cellfun(@(c) str2double(c{1}) + 1, channelNum);
        
        obj.MetaData.SizeC = numel(channelNum);
        
        % Get number of planes / time information
        switch S.ZAxisConversionTitle
            case 't'
                obj.MetaData.SizeZ = 1;
                obj.MetaData.SizeT = S.ZDim;
                obj.MetaData.SampleRate = S.ZAxisConversionConversionLinearScale;
            case 'z'
                obj.MetaData.SizeZ = S.ZDim;
                obj.MetaData.SizeT = 1;
                obj.MetaData.PhysicalSizeZ = S.ZAxisConversionConversionLinearScale;
        end

        % Set data dimension arrangement
        if obj.MetaData.SizeC > 1
            dataDimensionArrangement = 'CXY';
        else
            dataDimensionArrangement = 'XY';
        end

        if  obj.MetaData.SizeZ > 1
            dataDimensionArrangement(end+1) = 'Z';
        end
        if  obj.MetaData.SizeT > 1
            dataDimensionArrangement(end+1) = 'T';
        end

        obj.DataDimensionArrangement = dataDimensionArrangement;

        %Todo: Get from scan parameters
        obj.MetaData.PhysicalSizeYUnit = 'micrometer';
        obj.MetaData.PhysicalSizeXUnit = 'micrometer';  
        
        obj.MetaData.Class = obj.h5Type2matType(obj.DatasetInfoH5.Datasets.Datatype);

        for i = 1:obj.MetaData.SizeC
            obj.ImageScale(i) = S.(sprintf('Channel_%d_Conversion_ConversionLinearScale', i-1));
            obj.ImageOffset(i) = S.(sprintf('Channel_%d_Conversion_ConversionLinearOffset', i-1));
        end

        obj.assignDataSize()
        
        obj.assignDataType()
    end

    function assignDataSize(obj)
    %assignDataSize Assign DataSize (and DataDimensionArrangement)
    
        assert(~isempty(obj.DataDimensionArrangement), ...
            'DataDimensionArrangement is not assigned. Please report!')
    
        numDimensions = numel(obj.DataDimensionArrangement);
        dataSize = zeros(1, numDimensions);
    
        for i = 1:numDimensions
            switch obj.DataDimensionArrangement(i)
                case 'X'
                    dataSize(i) = obj.MetaData.SizeX;
                case 'Y'
                    dataSize(i) = obj.MetaData.SizeY;
                case 'C'
                    dataSize(i) = obj.MetaData.SizeC;
                case 'Z'
                    dataSize(i) = obj.MetaData.SizeZ;
                case 'T'
                    dataSize(i) = obj.MetaData.SizeT;
            end
        end
        
        obj.DataSize = dataSize;
    end
    
    function assignDataType(obj)
    %assignDataType Assign data type of acquired image data.    
        obj.DataType = obj.MetaData.Class;
    end
    
end

methods (Access = private)

    function datasetName = uiselectDatasetName(obj, listOfDataSets)
        datasetName = nansen.ui.dialog.uiSelectString(...
            listOfDataSets, 'single', 'Femtonics Recording');
    end

end

methods (Access = protected)

    function updateDataSize(obj)
        testImage = obj.readFrames(1);
        newFrameSize = [size(testImage, 1), size(testImage, 2)];
        %if ~isequal(newFrameSize, obj.DataSize(1:2))
            obj.DataSize(1:2) = newFrameSize;
        %end
    end
end
    
methods % Subclass specific methods
    
    function metadata = getFemtonicsRecordingInfo(obj)
    %getSciScanRecordingInfo Get recording info from the sciscan ini file
        
        metadata = struct();

        S = obj.DatasetInfoH5;

        attributesArray = S.Attributes;
        conversionMap = ophys.twophoton.femtonics.getMescMetadataDataConversionMap;

        S = utility.hdf5.attributes2struct(attributesArray, conversionMap);
        metadata = S;
        return

        
        % Get stack metadata
        

        
        % Get two-photon metadata

        % Todo: 
        % NumPixelX
        % NumPixelY



        % XDim
        % YAxisConversionUnitName
        % XAxisConversionUnitName



        % Resolve data type
        fileformat = obj.readinivar(inistring,'file.format');
        switch fileformat
            case {0, 1} % Todo: Add all possibilities..
                metadata.dataType = 'uint16';
            otherwise
                error('Not implemented yet, please report')
        end

        % Get pixel resolution of frames
        metadata.xpixels = obj.readinivar(inistring,'x.pixels');
        metadata.ypixels = obj.readinivar(inistring,'y.pixels');
        
        dataDimensionArrangement = 'XY';
        
        % Get number of recording channels
        metadata.nChannels = obj.readinivar(inistring,'no.of.channels');
        
        if metadata.nChannels > 1
            dataDimensionArrangement(end+1) = 'C'; 
        end
        
        try
            metadata.nFrames = obj.readinivar(inistring, 'no.of.frames.acquired');
        catch
            %metadata.nFrames = obj.readinivar(inistring, 'frame.count');  % <-- Not always correct 
            metadata.nFrames = obj.getFrameCount(metadata);
        end
        
        % Get info about whether recording is a volume (piezo, multi-plane) 
        % scan or a zstack
        metadata.experimentType = obj.readinivar(inistring, 'experiment.type');
        metadata.isPiezoActive = obj.readinivar(inistring, 'piezo.active');
        
        % Read number of planes if this is a ZStack recording or get volume
        % scan information if recording is a multiplane (piezo) scan
        if strcmp(metadata.experimentType, 'XYTZ')
            metadata.zSpacing = obj.readinivar(inistring, 'z.spacing');
            metadata.numFramesPerPlane = obj.readinivar(inistring, 'frames.per.plane');
            metadata.nPlanes = metadata.nFrames / metadata.numFramesPerPlane;
            dataDimensionArrangement = [dataDimensionArrangement, 'TZ'];

        elseif metadata.isPiezoActive
            metadata.nPlanes =  obj.readinivar(inistring, 'frames.per.z.cycle');
            dataDimensionArrangement = [dataDimensionArrangement, 'ZT'];

            % Todo: Get z-spacing
        else 
            metadata.zSpacing = 0;
            metadata.numFramesPerPlane = metadata.nFrames;
            metadata.nPlanes = 1;
            dataDimensionArrangement = [dataDimensionArrangement, 'T'];
        end
        
        obj.DataDimensionArrangement = dataDimensionArrangement;
        
        % Get spatial (physical) parameters for recording
        metadata.zoomFactor = obj.readinivar(inistring,'ZOOM');
        metadata.xcorrect = obj.readinivar(inistring,'x.correct');
        metadata.zPosition = abs(obj.readinivar(inistring,'setZ'));
        metadata.fovSizeX = abs(obj.readinivar(inistring,'x.fov')) * 1e6;
        metadata.fovSizeY = abs(obj.readinivar(inistring,'y.fov')) * 1e6;
        metadata.umPerPxX = metadata.fovSizeX / metadata.xpixels;
        metadata.umPerPxY = metadata.fovSizeY / metadata.ypixels;
                
        % Get temporal (physical) parameters for recording
        metadata.fps = obj.readinivar(inistring,'frames.p.sec');
        metadata.dt = 1/metadata.fps;
        
        
        % Get channel information % Todo...
        metadata.channelNumbers = [];
%         metadata.channelNames = {};
%         metadata.channelColor = {};
        for ch = 1:4
            chExpr = sprintf('save.ch.%d', ch);
            if obj.readinivar(inistring, chExpr) % save.ch.n = true/false
                % metadata.nChannels = metadata.nChannels + 1;
                metadata.channelNumbers(end+1) = ch;
%                 metadata.channelNames{end+1} = ['Ch', num2str(ch)];
%                 metadata.channelColor{end+1} = colors{ch};
            end
        end
    end
    
    function frameCount = getFrameCount(obj, metadata)
    %getFrameCount Get framecount based on frame size and file size
        L = dir(obj.FilePath);
        
        frameSize = [metadata.xpixels, metadata.ypixels, metadata.nChannels];
        byteSizePerFrame = obj.getImageDataByteSize(frameSize, metadata.dataType);
        
        byteSize = L.bytes;
        frameCount = byteSize ./ byteSizePerFrame;
    end
    
    function getChannelColors(obj)
        
        % Test this, initially it was done as below, but maybe that was to
        % resolve which channels were recorded.
        %metadata.nChannels = obj.readinivar(inistring, 'no.of.channels');
        
        % Get information about recorded channels

% % %         % Todo:
% % %         if metadata.microscope == 'OS1'
% % %             colors = {'Red', 'Green', 'N/A', 'N/A'};
% % %         else
% % %             colors = {'Green', 'Red', 'N/A', 'N/A'};
% % %         end
        
        
        
    end
    
end

methods % Implementation of abstract methods

    function data = readData(obj, subs)

        datasetName = obj.DatasetName;

        if obj.MetaData.SizeC > 1
            % Determine which channels to get

            % Set dataset name to correspond with channel
            error('Not implemented yet')
        else
            tmpDatasetName = [obj.DatasetName, '/Channel_0'];
            obj.DatasetName = tmpDatasetName;
            data = readData@nansen.stack.virtual.HDF5(obj, subs);
        end

        data = single( data ) * obj.ImageScale + obj.ImageOffset ;
        data = cast(data, obj.DataType);
        obj.DatasetName = datasetName;
    end

end


methods (Static)

    function numDataSets = countDataSets(h5Reference)
    % Count number of datasets in mesc (h5) file

        import nansen.stack.virtual.FemtoMesc
        h5Info = FemtoMesc.parseH5Reference(h5Reference);

        numRecordings = arrayfun( @(s) numel(s.Groups), h5Info.Groups );

        numDataSets = sum(numRecordings);
    end

    function recordingNames = listDataSetNames(h5Reference)

        import nansen.stack.virtual.FemtoMesc
        h5Info = FemtoMesc.parseH5Reference(h5Reference);

        recordingNames = arrayfun( @(s) {s.Groups.Name}, h5Info.Groups, 'uni', 0);
        recordingNames = cat(2, recordingNames{:});
    end

    function h5InfoStruct = parseH5Reference(h5Reference)
    %parseH5Reference Parses a h5 reference
    %
    %   h5Info = parseH5Reference(h5Reference) parses the h5Reference and
    %   returns a struct containing information about an entire HDF5 file.
    %
    %   The h5 reference can be a filename pointing to a mesc file or a
    %   struct containing h5 info. If input is a struct, an assertion is
    %   done to to make sure the struct looks like a h5 info struct.

        if ischar(h5Reference)
            if isfile(h5Reference)
                h5InfoStruct = h5info(h5Reference);
            else
                error('Character vector must point to an existing file')
            end

        elseif isstruct(h5Reference)
            assert(isfield(h5Reference, 'Groups'), ...
                'Expected struct to have a Groups field')
            h5InfoStruct = h5Reference;

        else
            error('Invalid input')
        end
    end

    function isValid = fileCheck(pathStr)
    %fileCheck Waterproof (?) test of whether this is a sciscan path
    %
    % Assume validity, abort if assumption fails.
        
        if isa(pathStr, 'cell')
            pathStr = pathStr{1};
        end
    
        % Check that pathStr starts with a datestr
        [folderPath, fileName, ext] = fileparts(pathStr);
        isValid = isequal( regexp(fileName, '\d{8}_\d{2}_\d{2}_\d{2}'), 1 );
        
        if ~isValid; return; end
        
        % Check for presence of .raw or .ini file.
        if isfolder(pathStr)
            L = dir(fullfile(pathStr, '*.raw'));
            if isempty(L)
                isValid = false; return;
            else
                rawFilePath = fullfile(L.folder, L.name);
                iniFilePath = strrep(rawFilePath, '.raw', '.ini');
            end

        elseif isfile(pathStr)
            if ~strcmp(ext, '.raw') && ~strcmp(ext, '.ini')
                isValid = false; return;
            elseif strcmp(ext, '.raw')
                rawFilePath = pathStr;
                iniFilePath = fullfile(folderPath, [fileName, '.ini']);
            elseif strcmp(ext, '.ini')
                iniFilePath = pathStr;
                rawFilePath = fullfile(folderPath, [fileName, '.raw']);
            end
        else
            isValid = false; return
        end
        
        isValid = isfile(rawFilePath) & isfile(iniFilePath);
        
        if ~isValid; return; end
        
        % Last check, is inifile what we expect...
        inistring = fileread(iniFilePath);
        
        sciscanVars = {'external.start.trigger.enable', 'aocard.model'};
        isValid = contains(inistring, sciscanVars);

    end
    
end

methods (Hidden) % Temp read performance plot
        
    function data = readDataPerformanceTest(obj, subs)
        
        persistent T i
        if isempty(T); T = zeros(1,1000); i=1; end; t0 = tic;
        
        data = obj.MemMap.Data.ImageArray(subs{:});
        data = swapbytes(data); % SciScan data is saved with bigendian?
        
        T(i) = toc(t0); i = i+1;
        if mod(i, 1000)==0
            figure; plot(T); i = 1; disp(mean(T))
        end
    end
    
end

end