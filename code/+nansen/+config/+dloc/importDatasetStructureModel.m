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
%   Every data location name and variable name is checked before anything
%   is added. A name that the project already has, or that the conversion
%   gives to two items, raises the error
%   NANSEN:ImportDatasetStructureModel:NameExists, which lists all such
%   names, and neither model is changed. Importing the same model twice
%   into one project therefore fails on the second attempt and leaves the
%   project as it was.
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

    clashes = [ ...
        "data location " + takenNames(itemNames(dataLocations, 'Name'), dataLocationModel.DataLocationNames), ...
        "variable " + takenNames(itemNames(variables, 'VariableName'), variableModel.VariableNames)];
    if ~isempty(clashes)
        error('NANSEN:ImportDatasetStructureModel:NameExists', ...
            ['The model was not imported, because these names are already in the project ', ...
            'or are given to two items of the model: %s. Rename or remove the existing items, ', ...
            'or rename them in the model, and import it again.'], strjoin(clashes, ', '))
    end

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

function names = itemNames(items, nameField)
%itemNames The names of struct items as a string row; empty for no items
    arguments
        items struct
        nameField (1,1) string
    end

    if isempty(items)
        names = string.empty(1, 0);
    else
        names = string({items.(nameField)});
    end
end

function names = takenNames(newNames, existingNames)
%takenNames Quoted new names that are already taken, or that occur more than once among the new names
    arguments
        newNames (1,:) string
        existingNames string
    end

    names = string.empty(1, 0);
    if isempty(newNames)
        return
    end

    [uniqueNames, ~, index] = unique(newNames, 'stable');
    isRepeated = reshape(accumarray(index(:), 1) > 1, 1, []);
    isTaken = ismember(uniqueNames, existingNames) | isRepeated;
    names = "'" + uniqueNames(isTaken) + "'";
end
