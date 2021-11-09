classdef SciScanRaw < nansen.stack.data.VirtualArray

    
properties (Access = private, Hidden)
    MemMap
end

properties (Hidden) % Todo: Add a twophoton mixin class for data preprocessing
    stretchCorrectMethod = 'imwarp'
    numFlybackLines = 8
end

    
methods % Structors
    
    function obj = SciScanRaw(filePath, varargin)
        
        % Open folder browser if there are no inputs.
        if nargin < 1; filePath = uigetdir; end
        
        obj@nansen.stack.data.VirtualArray(filePath, varargin{:})
    end
    
    function delete(obj)

        if ~isempty(obj.MemMap)
            clear obj.MemMap
        end

    end
    
end

methods % Implementation of VirtualArray abstract methods
    
    function data = readData(obj, subs)
        data = obj.MemMap.Data.ImageArray(subs{:});
        data = swapbytes(data); % SciScan data is saved with bigendian?
    end
    
    function data = readFrames(obj, frameIndex)
        
    end
       
    function writeFrames(obj, frameIndex, data)
        error('Not implemented yet')
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
    
        % Find fileName from folderPath
        if contains(filePath, '.raw')
            [folderPath, fileName, ext] = fileparts(filePath);
            fileName = strcat(fileName, ext);
        
        elseif contains(filePath, '.ini')
            [folderPath, fileName, ~] = fileparts(filePath);
            fileName = strcat(fileName, '.raw');
        
        elseif isfolder(filePath)
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
        
        obj.MetaData = obj.getSciScanRecordingInfo();

        obj.assignDataSize()
        
        obj.assignDataType()
        
    end
    
    function createMemoryMap(obj)
        
        % Create a memory map from the file
        mapFormat = {obj.DataType, obj.DataSize, 'ImageArray'}; % 'frames'
        obj.MemMap = memmapfile(obj.FilePath, 'Format', mapFormat);
        
% % %         % todo: add flyback removal
        
% % %         switch obj.stretchCorrectMethod
% % %             case {'imwarp', 'imresize'}
% % %                 testImage = obj.getFrameSet(1);
% % %                 
% % %                 obj.StackSize(1) = size(testImage, 2);
% % %                 obj.StackSize(2) = size(testImage, 1);
% % % 
% % %         end

    end
    
    function assignDataSize(obj)
                
        numChannels = obj.MetaData.nChannels;
        numPlanes = 1; % Todo: Add this from metadata.
        numTimepoints = obj.MetaData.nFrames;
        
        % Is this intentional??? I think so, see set dimensionorder...
        obj.DataSize = [obj.MetaData.xpixels, obj.MetaData.ypixels];
        obj.DataDimensionArrangement = 'XY';
        
        % Add length of channels if there is more than one channel
        if numChannels > 1
            obj.DataSize = [obj.DataSize, numChannels];
            obj.DataDimensionArrangement(end+1) = 'C';
        end
        
        % Add length of planes if there is more than one plane
        if numPlanes > 1
            obj.DataSize = [obj.DataSize, numPlanes];
            obj.DataDimensionArrangement(end+1) = 'Z';
        end
        
        % Add length of sampling dimension.
        if numTimepoints > 1
            obj.DataSize = [obj.DataSize, numTimepoints];
            obj.DataDimensionArrangement(end+1) = 'T';
        end

    end
    
    function assignDataType(obj)
        
        % Todo: Load image data class from metadata.

        % obj.DataType = obj.MetaData.fileformat?
        obj.DataType = 'uint16';
    end
    
end


    
methods % Subclass specific methods
    
    function metadata = getSciScanRecordingInfo(obj)
        
        % Todo: get number of planes for zstacks or volume imaging.
        
        inifilepath = strrep(obj.FilePath, '.raw', '.ini');
        inistring = fileread(inifilepath);

        metadata = struct();
        
        % Get data acquisition parameters for recording
        metadata.xpixels = obj.readinivar(inistring,'x.pixels');
        metadata.ypixels = obj.readinivar(inistring,'y.pixels');
        metadata.fps = obj.readinivar(inistring,'frames.p.sec');
        metadata.dt = 1/metadata.fps;
        metadata.nFrames = obj.readinivar(inistring, 'no.of.frames.acquired');

        % Get spatial parameters for recording
        metadata.zoomFactor = obj.readinivar(inistring,'ZOOM');
        metadata.xcorrect = obj.readinivar(inistring,'x.correct');
        metadata.zPosition = abs(obj.readinivar(inistring,'setZ'));
        metadata.fovSizeX = abs(obj.readinivar(inistring,'x.fov')) * 1e6;
        metadata.fovSizeY = abs(obj.readinivar(inistring,'y.fov')) * 1e6;
        metadata.umPerPxX = metadata.fovSizeX / metadata.xpixels;
        metadata.umPerPxY = metadata.fovSizeY / metadata.ypixels;
        
        metadata.numFramesPerPlane = obj.readinivar(inistring,'frames.per.plane');
        
        
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

        metadata.nChannels = 0;
        metadata.channelNumbers = [];
%         metadata.channelNames = {};
%         metadata.channelColor = {};
        for ch = 1:4
            chExpr = sprintf('save.ch.%d', ch);
            if strcmp(strtrim(obj.readinivar(inistring, chExpr)), 'TRUE')
                metadata.nChannels = metadata.nChannels + 1;
                metadata.channelNumbers(end+1) = ch;
%                 metadata.channelNames{end+1} = ['Ch', num2str(ch)];
%                 metadata.channelColor{end+1} = colors{ch};
            end
        end
        
        metadata.fileFormat = obj.readinivar(inistring, 'file.format');
        
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
                    varvalue = regexprep(s2{i}, ',', '.');
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
        end
        
        isValid = isfile(rawFilePath) & isfile(iniFilePath);
        
        if ~isValid; return; end
        
        % Last check, is inifile what we expect...
        inistring = fileread(iniFilePath);
        
        sciscanVars = {'external.start.trigger.enable', 'aocard.model'};
        isValid = contains(inistring, sciscanVars);

    end
    
end


end