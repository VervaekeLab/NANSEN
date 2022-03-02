function variableModel = initializeDataVariableModel(filePath, modules)
%initializeDataVariableModel Initialize a data variable model   
%   
%   initializeDataVariableModel(filePath) will initialize a data variable
%   model on the given filepath. The data variable model is a preset model
%   consisting of preset data variables that are part of the specified
%   modules. Some preconfigured modules can be found in 
%   ...Nansen/templates/datavariables
%   
%   variableModel = initializeDataVariableModel(filePath) returns the
%   initialized variableModel object.
%
%   Note: The data variable model can be configured manually or using the
%   VariableModelApp.
%
%   See also nansen.config.varmodel.VariableModel
%   nansen.config.varmodel.VariableModelApp

    if nargin < 2
        modules = {'ophys.twophoton'};
    end
    
    if ischar(modules); modules = {modules}; end

    % There should be a datalocation model in same file location:
    dlFilePath = strrep(filePath, 'filepath_settings.mat', 'datalocation_settings.mat');
    dataLocationModel = nansen.config.dloc.DataLocationModel(dlFilePath);
    defaultDataLocationItem = dataLocationModel.getDefaultDataLocation;

    variableModel = nansen.config.varmodel.VariableModel(filePath);
    
    % Get folder containing preset variables for modules
    variableTemplateDir = nansen.localpath('Data Variable Template Folder');
    addpath(variableTemplateDir)
    
    % Loop through given models
    for i = 1:numel(modules)
        
        thisModule = modules{i};
        getVariableListFcn = str2func([thisModule, '.getVariableList']);
        
        variableList = getVariableListFcn();
        
        % Insert variable specifications to the model
        for j = 1:numel(variableList)
            
            if strcmp(variableList(j).DataLocation, 'DEFAULT')
                variableList(j).DataLocation = defaultDataLocationItem.Name;
                variableList(j).DataLocationUuid = defaultDataLocationItem.Uuid;
            end
            
            variableModel.insertItem(variableList(j))
            
        end        
    end
    
    variableModel.save()
    
    if ~nargout
        clear variableModel
    end
    
end