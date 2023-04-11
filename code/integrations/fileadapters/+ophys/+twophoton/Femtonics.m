classdef Femtonics < nansen.dataio.FileAdapter
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
        SUPPORTED_FILE_TYPES = {'mesc'} % mes?
    end
    
% - - - - - - - - - - - - - METHODS - - - - - - - - - - - - - - - - - - - 

    methods (Access = protected)
        
        function imageStack = readData(obj, ~)
        %readData Read data from a sciscan file to a virtual ImageStack
            
            import nansen.stack.virtual.FemtoMesc
    
            % Todo: One image stack per virtual data...
            
            % Is this a single file or multi file recording?
            %filePathList = FileConcatenator.lookForMultipartFiles(obj.Filename, 3);
            
            %numRecordings = FemtoMesc.countDataSets(obj.Filename);
            datasetNames = FemtoMesc.listDataSetNames(obj.Filename);
                            
            % Create a virtualData object per fov.
            virtualData = nansen.stack.virtual.FemtoMesc.empty;
            for i = 1:numel(datasetNames)
                virtualData = [virtualData, ...
                    nansen.stack.virtual.FemtoMesc(obj.Filename, datasetNames{i})]; %#ok<AGROW> 
            end

            imageStack = arrayfun(@(vd) nansen.stack.ImageStack(vd), virtualData, 'UniformOutput', false);
            imageStack = [imageStack{:}];
        end
        
    end
    
    methods
        
        function save(~, ~)
            error('Can not save data to a Femtonics mesc file')
        end
        
        function imageStack = open(obj)
            imageStack = obj.load();
            %imviewer(imageStack)
        end
        
        function view(obj)
        %VIEW View the data in imviewer
            imageStack = obj.load();
            for i = 1:numel(imageStack)
                imviewer(imageStack(i))
            end
        end
        
    end
    
end