classdef TSMVoltageSeries < nansen.dataio.FileAdapter
%TSMVoltageSeries File adapter for a voltage series tsm file
%
%   This file adapter provides methods to load the data from a tsm
%   file to a virtual ImageStack object. This is a read-only file adapter.


% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 

    properties (Constant)
        DataType = 'ImageStack'
        Description = ''
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'tsm'}
    end
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - 

    methods (Access = protected)
        
        function imageStack = readData(obj, ~)
        %readData Read data from a sciscan file to a virtual ImageStack
            virtualData = nansen.stack.virtual.TSM(obj.Filename);
            imageStack = nansen.stack.ImageStack(virtualData);
        end
        
    end
    
    methods
        
        function save(~, ~)
            error('Can not save data to a TSM file')
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