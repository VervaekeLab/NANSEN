function S = bids()
%BIDS Template for datalocation organized based on bids
%
%   S = bids() returns a template for a datalocation organized according
%   to bids

    import nansen.config.dloc.DataLocationModel
    
    S = struct();
    S.x_type = 'Nansen Data Location Template Specification';
    S.x_version = '1.0.0';

    S.Name = 'BIDS';
    S.DataType = 'Recorded';
    
  % % Assign subfolder structure
    [S.SubfolderStructure(1:2)] = ...
        deal(DataLocationModel.getDefaultSubfolderStructure);
    
    S.SubfolderStructure(1).Type = 'Subject';
    S.SubfolderStructure(2).Type = 'Session';

  % % No metadata specification
    S.MetaDataDef = DataLocationModel.getDefaultMetadataStructure;
    S.MetaDataDef(1).SubfolderLevel = 1;
    S.MetaDataDef(1).StringDetectInput = '5:end';
    S.MetaDataDef(2).SubfolderLevel = 2;
    S.MetaDataDef(2).StringDetectInput = '5:end';
    
    % Export to module:
    targetPath = fullfile(nansen.common.constant.ModuleRootDirectory, ...
        '+nansen', '+module', '+general', '+core', 'resources', 'datalocations');

    fileName = 'bids.json';
    savePath = fullfile(targetPath, fileName);
    utility.io.savejson(savePath, S)
end

