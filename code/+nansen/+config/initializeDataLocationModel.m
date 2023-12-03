function dataLocationModel = initializeDataLocationModel(filePath)
%initializeDataLocationModel Initialize a datalocation model.
%
%   initializeDataLocationModel(filePath) will initialize a datalocation-
%   model on the given filepath. The data location model is a preset model
%   consisting of one datalocation for recorded data and one datalocation
%   for processed data. The datalocation for recorded data does not have 
%   a defined subfolderhierarchy, whereas the datalocation for processed
%   data is preconfigured with a subject/session subfolder hierarchy.
%   
%   dataLocationModel = initializeDataLocationModel(filePath) returns the
%   initialized dataLocationModel object.
%
%   Note: The datalocation model can be configured manually or using the
%   DataLocationModelApp.
%
%   See also nansen.config.dloc.DataLocationModel
%   nansen.config.dloc.DataLocationModelApp


    dataLocationModel = nansen.config.dloc.DataLocationModel(filePath);
        
    % Create a datalocation item for rawdata (recorded)
    newItem = dataLocationModel.getBlankItem();
    newItem.Name = 'Rawdata';
    newItem.Type = nansen.config.dloc.DataLocationType('recorded');

    dataLocationModel.insertItem(newItem)
    
    % Create a datalocation item for processed data
    newItem = dataLocationModel.getBlankItem();
    newItem.Name = 'Processed';
    newItem.Type = nansen.config.dloc.DataLocationType('processed');
    newItem.SubfolderStructure(1) = dataLocationModel.getDefaultSubfolderStructure;
    newItem.SubfolderStructure(1).Type = 'Animal';
    newItem.SubfolderStructure(2) = dataLocationModel.getDefaultSubfolderStructure;
    newItem.SubfolderStructure(2).Type = 'Session';
    
    dataLocationModel.insertItem(newItem)

    % Set the processed data location as the default.
    dataLocationModel.DefaultDataLocation = 'Processed'; 
    
    dataLocationModel.save()
    
    if ~nargout 
        clear dataLocationModel
    end

end