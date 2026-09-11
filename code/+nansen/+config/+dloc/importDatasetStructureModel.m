function report = importDatasetStructureModel(dsmConfig, dataLocationModel, variableModel, options)
%importDatasetStructureModel Add a Dataset Structure Model's data locations and variables to a project
%
%   Syntax:
%       report = nansen.config.dloc.importDatasetStructureModel( ...
%           dsmConfig, dataLocationModel, variableModel)
%
%       report = nansen.config.dloc.importDatasetStructureModel(..., ...
%           SessionEntity=name, SubjectEntity=name)
%
%   Converts the model with dsm2DataLocationModel, adds the data locations
%   to dataLocationModel and the variables to variableModel, and returns
%   the report of what was not mapped.
%
%   Adding a data location assigns it a new uuid, so each variable is
%   relinked to the uuid its data location was given.
%
%   Adding an item whose name is already in a model raises an error, so
%   importing the same model twice into one project fails on the second
%   attempt rather than creating duplicates.
%
%   Example:
%       project = nansen.getCurrentProject();
%       report = nansen.config.dloc.importDatasetStructureModel( ...
%           "garad-2022.json", project.DataLocationModel, project.VariableModel);
%       disp(report)
%
%   See also nansen.config.dloc.dsm2DataLocationModel

    arguments
        dsmConfig
        dataLocationModel (1,1) nansen.config.dloc.DataLocationModel
        variableModel (1,1) nansen.config.varmodel.VariableModel
        options.SessionEntity (1,1) string = missing
        options.SubjectEntity (1,1) string = missing
    end

    nameValueArgs = namedargs2cell(options);
    [dataLocations, variables, report] = ...
        nansen.config.dloc.dsm2DataLocationModel(dsmConfig, nameValueArgs{:});

    for i = 1:numel(dataLocations)
        placeholderUuid = dataLocations(i).Uuid;
        dataLocationModel.addDataLocation(dataLocations(i));
        assignedUuid = dataLocationModel.getDataLocation(dataLocations(i).Name).Uuid;

        for j = 1:numel(variables)
            if strcmp(variables(j).DataLocationUuid, placeholderUuid)
                variables(j).DataLocationUuid = assignedUuid;
            end
        end
    end

    for j = 1:numel(variables)
        variableModel.insertItem(variables(j));
    end
end
