classdef DataLocation < nansen.metadata.abstract.Item
    
    properties
        Type (1,1) nansen.dataio.datalocation.enum.DataLocationType = ...
             nansen.dataio.datalocation.enum.DataLocationType.RECORDED
        
        RootPath (1,:) nansen.dataio.datalocation.RootFolder
    
        FolderLevels (1,:) nansen.dataio.datalocation.FolderLevel

        MetadataExtractor (1,:) nansen.dataio.datalocation.MetadataExtractor

        DataSubfolders (1,:) string = string.empty
        ExamplePath
    end

end