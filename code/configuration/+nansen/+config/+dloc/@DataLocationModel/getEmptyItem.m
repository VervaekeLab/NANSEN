function S = getEmptyItem()

    import nansen.config.dloc.DataLocationModel

    S = struct;

    S.Name = '';
    S.RootPath = {'', ''};
    S.ExamplePath = '';
    S.DataSubfolders = {};

    S.SubfolderStructure = DataLocationModel.getDefaultSubfolderStructure();
    S.MetaDataDef = DataLocationModel.getDefaultMetadataStructure();
    
end