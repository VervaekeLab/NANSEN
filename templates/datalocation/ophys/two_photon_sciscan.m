function S = two_photon_sciscan()
%TWO_PHOTON_SCISCAN Template for sciscan data location
%
%   S = two_photon_sciscan() returns a template for a sciscan datalocation 

    import nansen.config.dloc.DataLocationModel
    
    S = struct();
    S.Name = 'SciScan 2P';
    S.DataType = 'Recorded';
    
  % % Assign subfolder structure 
    S.SubfolderStructure = DataLocationModel.getDefaultSubfolderStructure;
    
    S.SubfolderStructure(1).Type = 'Date';
    S.SubfolderStructure(1).Expression = '\d{4}_\d{2}_\d{2}';
    S.SubfolderStructure(2).Type = 'Session';
    
    
  % % Assign metadata definition struct
    S.MetaDataDef =  DataLocationModel.getDefaultMetadataStructure;
    S.MetaDataDef(2).SubfolderLevel = 2;
    S.MetaDataDef(2).StringDetectMode = 'ind';
    S.MetaDataDef(2).StringDetectInput = '19:end'; % Everything after datetime string
      
    S.MetaDataDef =  DataLocationModel.getDefaultMetadataStructure;
    S.MetaDataDef(3).SubfolderLevel = 1;
    S.MetaDataDef(3).StringDetectMode = 'ind';
    S.MetaDataDef(3).StringDetectInput = '1:10'; % name of folder: yyyy_mm_dd
    S.MetaDataDef(3).StringFormat = 'yyyy_MM_dd';
    
    S.MetaDataDef =  DataLocationModel.getDefaultMetadataStructure;
    S.MetaDataDef(4).SubfolderLevel = 2;
    S.MetaDataDef(4).StringDetectMode = 'ind';
    S.MetaDataDef(4).StringDetectInput = '10:17'; 
    S.MetaDataDef(4).StringFormat = 'HH_mm_ss';
    
end

