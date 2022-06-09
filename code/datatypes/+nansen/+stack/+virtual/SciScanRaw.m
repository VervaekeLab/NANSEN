classdef SciScanRaw < nansen.stack.data.VirtualArray & nansen.stack.utility.TwoPhotonRecording
%SciScanRaw Virtual data adapter for a sciscan raw file

properties (Constant, Hidden)
    FILE_PERMISSION = 'read' % SciScan files should only be read from
end

properties (Access = private, Hidden)
    MemMap                   % A matlab memorymap for the binary raw file
end


methods (Static)
    
    function nvPairs = getDefaultPreprocessingParams()
        nvPairs = {'NumFlybackLines', 8, 'StretchCorrectionMethod', 'imwarp'};
    end
    
end
    
methods % Structors
    
    function obj = SciScanRaw(filePath, varargin)
    %SciScanRaw Create a virtual data adapter for SciScan raw file  
        % Open folder browser if there are no inputs.
        if nargin < 1; filePath = uigetdir; end
                
        obj@nansen.stack.utility.TwoPhotonRecording(varargin{:})
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
    end
    
    function delete(obj)
        if ~isempty(obj.MemMap)
            obj.MemMap = [];
        end
    end
    
end

methods % Implementation of VirtualArray abstract methods
    
    function data = readData(obj, subs)
    %readData Read data from SciScan raw file
    %
    % Override readData of VirtualArray to read data from memorymap
    
        data = obj.MemMap.Data.ImageArray(subs{:});
        data = swapbytes(data); % SciScan data is saved with bigendian.
        % Todo: is this always the case?
        
        if obj.PreprocessDataEnabled
            data = obj.processData(data, subs);
        end
    end
    
    function data = readFrameSet(obj, frameIndex)
        % Todo
    end
    
    function data = readFrames(obj, frameIndex) % Todo: Remove
        subs = repmat({':'}, 1, ndims(obj));
        subs{end} = frameIndex;
        data = obj.readData(subs);
    end
    
    function writeFrameSet(obj, frameIndex, data) %#ok<INUSD>
        error('Writing to a raw image data file is not supported')
    end
       
    function writeFrames(obj, frameIndex, data) %#ok<INUSD>
        error('Writing to a raw image data file is not supported')
    end
    
end

methods (Access = protected) % Implementation of abstract methods
        
    function assignFilePath(obj, filePath, ~)
    %ASSIGNFILEPATH Assign path to the raw imaging data file.
    %
    %   Resolve whether the input pathString is pointing to the recording
    %   .ini file, the recording .raw file or the recording folder.
    
        if isa(filePath, 'cell')
            filePath = filePath{1};
        end
    
        
        if contains(filePath, '.raw')
            [folderPath, fileName, ext] = fileparts(filePath);
            fileName = strcat(fileName, ext);
        
        elseif contains(filePath, '.ini')
            [folderPath, fileName, ~] = fileparts(filePath);
            fileName = strcat(fileName, '.raw');
        
        elseif isfolder(filePath) % Find fileName from folderPath
            folderPath = filePath;
            listing = dir(fullfile(folderPath, '*.raw'));
            fileName = listing(1).name;
            if isempty(fileName) 
                error('Did not find raw file in the specified folder')
            end
            
        else
            error('Something went wrong. Filepath does not point to a SciScan recording.')
        end
        
        % Todo: Validate filepath based on filename before assigning. Could
        % potentially be the path to a different raw file.
        obj.FilePath = fullfile(folderPath, fileName);
        
    end
    
    function getFileInfo(obj)
    %getFileInfo Get file info and assign to properties
    
        S = obj.getSciScanRecordingInfo();
        
        % Specify data dimension sizes
        obj.MetaData.SizeX = S.xpixels;
        obj.MetaData.SizeY = S.ypixels;
        obj.MetaData.SizeZ = S.nPlanes;
        obj.MetaData.SizeC = S.nChannels;
        obj.MetaData.SizeT = S.nFrames/S.nPlanes;
        
        % Specify physical sizes
        obj.MetaData.SampleRate = S.fps;
        obj.MetaData.PhysicalSizeY = S.umPerPxY;
        obj.MetaData.PhysicalSizeYUnit = 'micrometer';
        obj.MetaData.PhysicalSizeX = S.umPerPxX;
        obj.MetaData.PhysicalSizeXUnit = 'micrometer';  
        
        obj.MetaData.Class = S.dataType;
        
        % Necessary for image preprocessing
        obj.MetaData.set('zoomFactor', S.zoomFactor)
        obj.MetaData.set('xcorrect', S.xcorrect)

        obj.assignDataSize()
        
        obj.assignDataType()
    end
    
    function createMemoryMap(obj)
    %createMemoryMap Create a memory map for the binary file
    
        % Create a memory map from the file
        mapFormat = {obj.DataType, obj.DataSize, 'ImageArray'}; % 'frames'
        obj.MemMap = memmapfile(obj.FilePath, 'Format', mapFormat);
        
        if obj.PreprocessDataEnabled
            obj.updateDataSize() % Preprocessing might change the frame size
        end
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

methods
    
    function enablePreprocessing(obj)
    %enablePreprocessing Enable default preprocessing of sciscan raw data
    
        obj.assignDefaultPreprocessingParams()
               
        if obj.PreprocessDataEnabled
            obj.updateDataSize() % Preprocessing might change the frame size
        end
    end
    
    function disablePreprocessing(obj)
    %disablePreprocessing Disable default preprocessing of sciscan raw data
        
        obj.NumFlybackLines = 0;
        obj.StretchCorrectionMethod = 'none';
        obj.CorrectBidirectionalOffset = false;
               
        obj.updateDataSize()
    end
    
end

methods (Access = protected)
    function assignDefaultPreprocessingParams(obj)
        obj.NumFlybackLines = 8;
        obj.StretchCorrectionMethod = 'imwarp';
    end
    
    function updateDataSize(obj)
        testImage = obj.readFrames(1);
        newFrameSize = [size(testImage, 1), size(testImage, 2)];
        %if ~isequal(newFrameSize, obj.DataSize(1:2))
            obj.DataSize(1:2) = newFrameSize;
        %end
    end
end
    
methods % Subclass specific methods
    
    function metadata = getSciScanRecordingInfo(obj)
    %getSciScanRecordingInfo Get recording info from the sciscan ini file
    
        inifilepath = strrep(obj.FilePath, '.raw', '.ini');
        inistring = fileread(inifilepath);

        metadata = struct();
       
        metadata.experimentType = obj.readinivar(inistring, 'experiment.type');
        
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
        
        % Get volume scan information
        metadata.isPiezoActive = obj.readinivar(inistring, 'piezo.active');
        if metadata.isPiezoActive
            metadata.nPlanes =  obj.readinivar(inistring, 'frames.per.z.cycle');
        else
            metadata.nPlanes = 1;
        end
        
        % Read number of planes is this is a ZStack recording
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

methods (Static)
    
    function varvalue = readinivar(inistring, variablename)
    %readinivar Function for reading variables from a sciscan ini file.
    
        ind1=regexp([inistring ' '],variablename);
        ind2=regexp(inistring,'\n');
        ind2(end+1) = numel(inistring);

        varvalue=[];

        if ~isempty(ind1)

            varline=inistring(ind1(1):(ind2(ind2>ind1(1))));

            s2=regexp(varline,'\=|\"','split');

            for i=2:length(s2)
                if sum(size(strtrim(s2{i})))
                    
                    varvalue = strtrim(s2{i});
                    varvalue = regexprep(varvalue, ',', '.');
                    
                    if any( strcmp(varvalue, {'TRUE', 'FALSE'}) )
                        varvalue = eval(lower(varvalue));
                    else
                        varvalue = str2num(varvalue);
                        if ~isempty(varvalue)
                            break
                        else
                            varvalue=s2{i};
                            break
                        end
                    end
                end
            end
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