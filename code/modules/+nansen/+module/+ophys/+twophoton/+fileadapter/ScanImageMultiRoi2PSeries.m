classdef ScanImageMultiRoi2PSeries < nansen.dataio.FileAdapter
%ScanImageMultiRoi2PSeries File adapter for a raw scanimage two-photon
% series file or set of files with multiple rois (field of views)
%
%   This file adapter provides methods to load the data from a scanimage
%   file to a virtual ImageStack object. This is a read-only file adapter.

% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - -

    properties (Constant)
        DataType = 'ImageStack'
        Description = ''
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'tif', 'tiff'}
    end
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - -

    methods (Access = protected)
        
        function imageStack = readData(obj, ~)
        %readData Read data from a sciscan file to a virtual ImageStack
            
            import nansen.stack.FileConcatenator
            import nansen.stack.virtual.ScanImageTiff

            % Todo: One image stack per virtual data...
            
            % Is this a single file or multi file recording?
            filePathList = FileConcatenator.lookForMultipartFiles(obj.Filename, 3);
            
            isMultiRoi = ScanImageTiff.checkIfMultiRoi(filePathList);
            if ~isMultiRoi
                error('FileAdapter:RecordingNotMultiRoi', ...
                    'This recording is not a multi roi recording')
            end
                            
            % Create a virtualData object per fov.
            virtualData = nansen.stack.virtual.ScanImageMultiRoiTiff.empty;
            for i = 1:numel(filePathList)
                virtualData = [virtualData, ...
                    nansen.stack.virtual.ScanImageMultiRoiTiff(filePathList{i})]; %#ok<AGROW>
            end

            imageStack = arrayfun(@(vd) nansen.stack.ImageStack(vd), virtualData, 'UniformOutput', false);
            imageStack = [imageStack{:}];
        end
    end
    
    methods
        
        function save(~, ~)
            error('Can not save data to a ScanImage multi roi file')
        end
        
        function imageStack = open(obj)
            imageStack = obj.load();
            %imviewer(imageStack)
        end
        
        function view(obj)
        %VIEW View the sciscan data in imviewer
            imageStack = obj.load();
            % Todo: Open one imviewer per FOV

            for i = 1:numel(imageStack)
                imviewer(imageStack(i))
            end
        end
    end
end
