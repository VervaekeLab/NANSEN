function S = getBlankItem()

    import nansen.config.dloc.DataLocationModel

    S = struct;

    S.Name = '';
    S.Type = nansen.config.dloc.DataLocationType('Processed');
    S.RootPath = struct('Key', {}, 'Value', {}, 'DiskName', {}); % Use a key/value struct array for path list in order to work across systems
    S.ExamplePath = '';
    S.DataSubfolders = {};

    S.SubfolderStructure = DataLocationModel.getDefaultSubfolderStructure();
    S.MetaDataDef = DataLocationModel.getDefaultMetadataStructure();
    
end
