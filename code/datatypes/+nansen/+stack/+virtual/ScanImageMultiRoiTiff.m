classdef ScanImageMultiRoiTiff < nansen.stack.virtual.ScanImageTiff
%ScanImageTiff Virtual data adapter for a scanimage tiff file

% Note: Multi plane stacks are not supported.

% Superclass properties:

% properties (Access = private, Hidden)
%     hTiffStack  % TIFFStack object
%     tiffInfo Tiff    % TIFF object
% end

% properties (Access = private, Hidden) % File Info
%     UseTiffStack = false % Flag whether to use DylanMuirs TIFFStack class
% 
%     NumChannels_
%     NumPlanes_
%     NumTimepoints_
%     
%     FileConcatenator
%     FrameIndexMap   % Holds frame indices for interleaved dimensions (numC x numZ x numT)
%                     % Todo: Replace with deinterleaver..
%     
%     FilePathList
% end

properties
    FovId = 1
end

properties (SetAccess = private)
    NumFovs = 1
end

properties (Access = private)
    FovInfo % Struct containing information about multiple FOVs.
end

methods % Structors
    
    function obj = ScanImageMultiRoiTiff(filePath, varargin)
        
        % Todo: document and make sure it always works to receive a tiff
        % object instead of a filepath as input
        
        if nargin < 1 || ~exist('filePath', 'var')
            filePath = '';
        end

        obj@nansen.stack.virtual.ScanImageTiff(filePath, varargin{:})
        obj.Description = sprintf('Fov%d', obj.FovId);

        if obj.FovId == 1 && ~isempty(obj.FilePath)
            [~, obj.NumFovs] = nansen.stack.virtual.ScanImageTiff.checkIfMultiRoi(obj.tiffInfo);
            if obj.NumFovs > 1
                obj(obj.NumFovs) = nansen.stack.virtual.ScanImageMultiRoiTiff();
                for iFov = 2:obj(1).NumFovs
                    obj(iFov) = nansen.stack.virtual.ScanImageMultiRoiTiff(filePath, varargin{:}, 'FovId', iFov, 'NumFovs', obj(1).NumFovs);
                end
            end
        end

    end
    
    function delete(obj)
        % Todo: delete array
        if ~isempty(obj.hTiffStack)
            delete(obj.hTiffStack)
        end
        
        if ~isempty(obj.tiffInfo)
            for i = 1:numel(obj.tiffInfo)
                close(obj.tiffInfo(i))
            end
        end

    end
    
end


methods (Access = protected) % Implementation of abstract methods
        
    function assignFilePath(obj, filePath, ~)
        
        import('nansen.stack.FileConcatenator')
        
        if isa(filePath, 'cell')
            if ischar( filePath{1} )
                obj.FilePath = filePath{1};
            elseif isa(filePath{1}, 'Tiff')
            	obj.tiffInfo = filePath{1};
                obj.FilePath = obj.tiffInfo.FileName;
            end
            
        elseif isa(filePath, 'char') || isa(filePath, 'string')
            obj.FilePath = char(filePath);
            
        elseif isa(filePath, 'Tiff')
            obj.tiffInfo = filePath;
            obj.FilePath = obj.tiffInfo.Filename;
        end
                
        % Determine whether TIFFStack is on path and should be used.
        if exist('TIFFStack', 'file') == 2
            obj.UseTiffStack = false;
        end
    end
    
    function getFileInfo(obj)
        
        % Todo: If metadata is assigned, skip 
        
        if isempty( obj.tiffInfo )
            obj.tiffInfo = Tiff(obj.FilePath);
        end
        
        % Get information about current fovs.
        obj.FovInfo = obj.getScanImageFovParams();

        obj.MetaData.SizeY = obj.FovInfo.pixelResolutionXY(2);
        obj.MetaData.SizeX = obj.FovInfo.pixelResolutionXY(1);

        scanimageParams = obj.getScanParameters();
        scanimageParams.fovInfo = obj.FovInfo;
        obj.assignScanImageParametersToMetadata(scanimageParams)
    
        obj.assignDataSize();
        obj.assignDataType()
    end
  
end

methods % Implementation of VirtualArray abstract methods
    
    function data = readData(obj, subs)
    %readData Reads data from tiff file
    %
    %   See also nansen.stack.data.VirtualArray/readData
    
        if ~isempty(obj.hTiffStack)
            % Todo: Update with frame subregion...
            data = obj.hTiffStack(subs{:});
        else
            data = obj.readDataTiff(subs);
        end
    end
    
    function data = readDataTiff(obj, subs)
        
        % Determine size of requested data
        dataSize = obj.getOutSize(subs);
        
        % Preallocate data
        data = zeros(dataSize, obj.DataType);
        insertSub = arrayfun(@(n) 1:n, dataSize, 'uni', 0);
        
        global waitbar
        useWaitbar = false;
        if ~isempty(waitbar); useWaitbar = true; end
        
        if useWaitbar
            waitbar(0, 'Loading image frames')
            updateRate = round(dataSize(end)/50);
        end
        
        frameInd = obj.FrameIndexMap(subs{3:end});

        [m, n, p] = size(frameInd);
        numFramesToLoad = m*n*p;

        count = 1;
        
        % Loop through frames and load into data.
        for k = 1:p
            for j = 1:n
                for i = 1:m
                    frameNum = frameInd(count);
                    insertSub(3:5) = {i, j, k};
                    
                    %[fileNum, frameNumInFile] = obj.FileConcatenator.getFrameFileInd(frameNum);
                    fileNum = 1; frameNumInFile = frameNum;
                    obj.tiffInfo(fileNum).setDirectory(frameNumInFile);
                    
                    %obj.tiffInfo.setDirectory(frameNum);
                    iFrameData = obj.tiffInfo(fileNum).read();
                                        
                    xInd = obj.FovInfo.fovLimX(1):obj.FovInfo.fovLimX(2);
                    yInd = obj.FovInfo.fovLimY(1):obj.FovInfo.fovLimY(2);
                    data(insertSub{:}) = iFrameData(yInd, xInd);%todo

                    count = count + 1;
            
                    if useWaitbar
                        if mod(count, updateRate) == 0
                            waitbar(count/numFramesToLoad, 'Loading image frames')
                        end
                    end
                end
            end
        end
        
        data = obj.cropData(data, subs);
    end
    
    function writeFrames(obj, frameIndex, data)
        error('Not implemented yet')
    end
    
end


methods (Access = protected)
    
    function sIFovParams = getScanImageFovParams(obj)

        % Get multi FOV information
        %scanImageTag = obj.tiffInfo(i).getTag('Software');
                 
        % ScanImage writes information about Rois to the Artist tag
        artistTagValue = obj.tiffInfo.getTag('Artist');
        data = jsondecode(artistTagValue);
        numRois = numel( data.RoiGroups.imagingRoiGroup.rois );
        
        thisFov = data.RoiGroups.imagingRoiGroup.rois(obj.FovId);
        sIFovParams.pixelResolutionXY = thisFov.scanfields(1).pixelResolutionXY';
        sIFovParams.centerXY = thisFov.scanfields(1).centerXY';
        
        % Get height of each individual FOV in pixels
        heightPerFov = arrayfun(@(s) ...
            s.scanfields(1).pixelResolutionXY(2), ...
            data.RoiGroups.imagingRoiGroup.rois );
        
        % Calculate number of flyback lines per FOV
        imageLengthWoFlybackLines = sum( heightPerFov );
        fullImageLength = obj.tiffInfo.getTag('ImageLength');
        numFlybackLines = fullImageLength - imageLengthWoFlybackLines;
        numFlybackLinesPerFov = numFlybackLines / numRois;

        % Calculate x and y- index limits for fov.
        sIFovParams.fovLimX = [1, sIFovParams.pixelResolutionXY(1)];
        y1 = sum(heightPerFov(1:obj.FovId-1)) + numFlybackLinesPerFov * obj.FovId + 1;
        y2 = y1 + heightPerFov(obj.FovId) - 1;
        sIFovParams.fovLimY = [y1, y2];
    end

end

end