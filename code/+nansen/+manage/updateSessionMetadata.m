function [updatedVariableNames, failureMessage] = updateSessionMetadata(sessionTable, dataLocationModel)
%updateSessionMetadata Extract subject IDs, dates and times of sessions again
%
%   updatedVariableNames = nansen.manage.updateSessionMetadata(sessionTable, dataLocationModel)
%   extracts the subjectID, Date and Time of every session in sessionTable
%   from the paths of the session's folders, using the metadata definitions
%   of dataLocationModel (the "Metadata Initialization" page of the data
%   location editor). Values that differ from those in the table are
%   written to sessionTable. updatedVariableNames is a string array with
%   the names of the columns where at least one value changed.
%
%   The data locations of a session are tried in the order of
%   dataLocationModel, and the first one that gives a value is used. This
%   is the rule that assigns these values when a session is added to the
%   table. A session keeps its current value when no data location gives a
%   value, for example when a pattern matches nothing, or when extraction
%   raises an error. Times are compared by their time of day.
%
%   The sessionID column is not updated, because a session ID identifies a
%   row of the table. A change to how session IDs are extracted needs a new
%   session table, which nansen.configureProject creates.
%
%   [updatedVariableNames, failureMessage] = nansen.manage.updateSessionMetadata(__)
%   also returns a message that names, for each column, the sessions for
%   which extraction raised an error and the first error message.
%   failureMessage is "" when no extraction raised an error.
%
%   See also nansen.manage.updateSessionDatalocations,
%            nansen.config.dloc.DataLocationModel/getMetadataValue

    arguments
        sessionTable (1,1) nansen.metadata.MetaTable
        dataLocationModel (1,1) nansen.config.dloc.DataLocationModel
    end

    updatedVariableNames = string.empty(1, 0);
    failureMessage = "";

    entries = sessionTable.entries;
    if isempty(entries) || ~ismember('DataLocation', entries.Properties.VariableNames)
        return
    end

    variableNames = ["subjectID", "Date", "Time"];
    definitionNames = ["Subject ID", "Experiment Date", "Experiment Time"];

    isInTable = ismember(variableNames, entries.Properties.VariableNames);
    variableNames = variableNames(isInTable);
    definitionNames = definitionNames(isInTable);

    dataLocationColumn = entries.DataLocation;

    numSessions = height(entries);
    numVariables = numel(variableNames);
    hasFailed = false(numSessions, numVariables);
    firstErrorMessages = strings(1, numVariables);
    isUpdated = false(1, numVariables);

    for iVariable = 1:numVariables
        variableName = variableNames(iVariable);

        currentValues = getColumnValues(entries, variableName);
        newValues = currentValues;
        isChanged = false(numSessions, 1);

        for iSession = 1:numSessions
            try
                value = dataLocationModel.getMetadataValue(definitionNames(iVariable), ...
                    getDataLocations(dataLocationColumn, iSession));
            catch exception
                hasFailed(iSession, iVariable) = true;
                if firstErrorMessages(iVariable) == ""
                    firstErrorMessages(iVariable) = exception.message;
                end
                continue
            end

            if ~isempty(value) && ...
                    ~isSameValue(variableName, currentValues{iSession}, value)
                newValues{iSession} = value;
                isChanged(iSession) = true;
            end
        end

        if any(isChanged)
            writeColumnValues(sessionTable, variableName, find(isChanged), newValues)
            isUpdated(iVariable) = true;
        end
    end

    updatedVariableNames = variableNames(isUpdated);

    if any(hasFailed(:))
        sessionLabels = getSessionLabels(entries);
        failureMessage = createFailureMessage(sessionLabels, hasFailed, ...
            variableNames, firstErrorMessages);
    end
end

function dataLocations = getDataLocations(dataLocationColumn, rowIndex)
%getDataLocations Data locations of a row of the table
%
%   A struct without a uuid is in the format used before data locations
%   had one, and can not be matched to a data location model. Such a row
%   gives an empty struct, like a row without data locations.
    if iscell(dataLocationColumn)
        dataLocations = dataLocationColumn{rowIndex};
    else
        dataLocations = dataLocationColumn(rowIndex, :);
    end

    if ~isstruct(dataLocations) || ~isfield(dataLocations, 'Uuid')
        dataLocations = struct.empty;
    end
end

function tf = isSameValue(variableName, currentValue, newValue)
%isSameValue True when a new value equals the current value of a column
%
%   Values of different types differ, so that a date extracted as a
%   datetime value replaces the same date stored as text. A time is parsed
%   from text without a date, and datetime gives it the date of the day it
%   is parsed, so times are compared by their time of day.
    isText = @(value) ischar(value) || (isstring(value) && isscalar(value));
    isScalarDatetime = @(value) isdatetime(value) && isscalar(value);

    if isText(currentValue) && isText(newValue)
        tf = strcmp(currentValue, newValue);
    elseif isScalarDatetime(currentValue) && isScalarDatetime(newValue)
        if variableName == "Time"
            tf = isequaln(timeofday(currentValue), timeofday(newValue));
        else
            tf = isequaln(currentValue, newValue);
        end
    else
        tf = strcmp(class(currentValue), class(newValue)) && isequaln(currentValue, newValue);
    end
end

function values = getColumnValues(entries, variableName)
%getColumnValues Values of a table column as a cell array with one cell per row
    columnValues = entries.(variableName);
    if iscell(columnValues)
        values = columnValues;
    else
        values = num2cell(columnValues);
    end
end

function writeColumnValues(sessionTable, variableName, rowIndices, columnValues)
%writeColumnValues Write new values to rows of a column, keeping one value type
%
%   A date or time is a datetime value when its metadata definition has a
%   format, and text otherwise, so adding or removing a format changes the
%   type of the values. A column whose values all become datetime values
%   is replaced by a datetime column, and a datetime column that gets text
%   values is replaced by a cell column. Otherwise, only the changed rows
%   are written.

    isDatetimeColumn = isdatetime(sessionTable.entries.(variableName));
    isDatetimeValue = cellfun(@(value) isdatetime(value) && isscalar(value), columnValues);

    if all(isDatetimeValue) && ~isDatetimeColumn
        sessionTable.replaceDataColumn(variableName, vertcat(columnValues{:}))
    elseif ~all(isDatetimeValue) && isDatetimeColumn
        sessionTable.replaceDataColumn(variableName, columnValues)
    else
        sessionTable.editEntries(rowIndices, variableName, columnValues(rowIndices))
    end
end

function sessionLabels = getSessionLabels(entries)
%getSessionLabels Text that identifies each session in a message
    numSessions = height(entries);
    if ismember('sessionID', entries.Properties.VariableNames)
        sessionLabels = string(entries.sessionID);
    else
        sessionLabels = "row " + string((1:numSessions)');
    end
end

function message = createFailureMessage(sessionLabels, hasFailed, variableNames, firstErrorMessages)
%createFailureMessage Describe the extractions that raised an error
    maxNumLabels = 3;

    failedVariableIndices = find(any(hasFailed, 1));
    paragraphs = strings(1, numel(failedVariableIndices));

    for i = 1:numel(failedVariableIndices)
        iVariable = failedVariableIndices(i);
        failedLabels = sessionLabels(hasFailed(:, iVariable));
        numFailed = numel(failedLabels);

        labelList = strjoin(failedLabels(1:min(numFailed, maxNumLabels)), ", ");
        if numFailed > maxNumLabels
            labelList = sprintf("%s and %d more", labelList, numFailed - maxNumLabels);
        end

        paragraphs(i) = sprintf("%s could not be extracted for %d session(s): %s.\nFirst error: %s", ...
            variableNames(iVariable), numFailed, labelList, firstErrorMessages(iVariable));
    end

    message = sprintf("%s\n\nThese sessions keep their current values.", ...
        strjoin(paragraphs, [newline, newline]));
end
