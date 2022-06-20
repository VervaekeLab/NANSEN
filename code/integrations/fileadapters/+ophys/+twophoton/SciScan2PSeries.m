classdef SciScan2PSeries < nansen.dataio.FileAdapter
%SciScanRawFile File adapter for a raw sciscan two-photon series file
%
%   This file adapter provides methods to load the data from a sciscan raw
%   file to a virtual ImageStack object. This is a read-only file adapter.


% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 

    properties (Constant)
        DataType = 'ImageStack'
        Description = ''
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'raw'}
    end
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - 

    methods (Access = protected)
        
        function imageStack = readData(obj, ~)
        %readData Read data from a sciscan file to a virtual ImageStack
            virtualData = nansen.stack.virtual.SciScanRaw(obj.Filename);
            imageStack = nansen.stack.ImageStack(virtualData);
        end
        
    end
    
    methods
        
        function save(~, ~)
            error('Can not save data to a SciScan raw file')
        end
        
        function imageStack = open(obj)
            imageStack = obj.load();
            %imviewer(imageStack)
        end
        
        function view(obj)
        %VIEW View the sciscan data in imviewer
            imageStack = obj.load();
            imviewer(imageStack)
        end
        
    end
    
end