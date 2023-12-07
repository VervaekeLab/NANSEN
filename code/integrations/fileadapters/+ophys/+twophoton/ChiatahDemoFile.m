classdef ChiatahDemoFile < nansen.dataio.FileAdapter
%ChiatahDemoFile File adapter for a chiatah demo two-photon series file
%
%   This file adapter provides methods to load the data from a chiatah h5
%   demo file to a virtual ImageStack object. This is a read-only file adapter.


% - - - - - - - - - - - - PROPERTIES - - - - - - - - - - - - - - - - - - - 

    properties (Constant)
        DataType = 'ImageStack'
        Description = ''
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'h5'}
    end
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - 

    methods (Access = protected)
        
        function imageStack = readData(obj, ~)
        %readData Read data from a chiatah demo file to a virtual ImageStack
            virtualData = nansen.stack.virtual.HDF5(obj.Filename, '/1');
            imageStack = nansen.stack.ImageStack(virtualData);
        end
        
    end
    
    methods
        
        function save(~, ~)
            error('Can not save data to a Chiatah demo file')
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