function T = formatTableForDisplay(metaTable, columnIndices, rowIndices)
%formatTableForDisplay Format a MetaTable's cells for UI display
%
%   T = formatTableForDisplay(metaTable) formats all cells.
%   T = formatTableForDisplay(metaTable, columnIndices, rowIndices)
%       formats specified columns and rows.
%
%   Converts special data types (categorical, enum, struct, datetime,
%   custom display objects) to display strings.
%
%   See also: nansen.metadata.MetaTable

    import nansen.metadata.utility.getColumnFormatter

    if nargin < 2 % Get all columns
        columnIndices = 1:size(metaTable.entries, 2);
    end
    if nargin < 3 % Get all rows
        rowIndices = 1:size(metaTable.entries, 1);
    end

    if isempty(metaTable.entries)
        T = metaTable.entries; return
    end

    % Subselect the part of the table that should be formatted
    T = metaTable.entries(rowIndices, columnIndices);
    variableNames = T.Properties.VariableNames;

    % Check if any of the columns contain structs
    firstRowData = table2cell( metaTable.entries(1, columnIndices) );

    % Create a cell array to hold formatting functions for each column
    formattingFcn = cell(size(firstRowData));

    % Step 0: (Do this first)
    % Note, this is done before checking for enum on purpose (Todo: Adapt special enum classes to also use the CompactDisplayProvider...)
    isCustomDisplay = @(x) isa(x, 'matlab.mixin.CustomCompactDisplayProvider');
    isCustomDisplayObj = cellfun(@(cell) isCustomDisplay(cell), firstRowData, 'uni', 1);
    formattingFcn(isCustomDisplayObj) = {@(o) getCustomDisplayString(o)};

    % Step 1: Specify formatting based on special data types.
    isCategorical = cellfun(@iscategorical, firstRowData);
    formattingFcn(isCategorical) = {'char'};

    isEnum = cellfun(@isenum, firstRowData);
    formattingFcn(isEnum) = {'char'};

    isString = cellfun(@isstring, firstRowData);
    formattingFcn(isString) = {'char'}; % uiw.widget.Table does is not compatible with strings.

    isStruct = cellfun(@(c) isstruct(c), firstRowData);
    formattingFcn(isStruct) = {'dispStruct'};

    isDatetime = cellfun(@(c) isdatetime(c), firstRowData);
    formattingFcn(isDatetime) = {'datetime'};

    % Step 2: Get nansen table variables formatters.
    tableClass = lower( metaTable.getTableType() );
    [fcnHandles, names] = getColumnFormatter(variableNames, tableClass);

    for i = 1:numel(names)
        isMatch = strcmp(variableNames, names{i});
        if any( isMatch )
            formattingFcn{isMatch} = fcnHandles{i};
        end
    end

    % Step 3: does the data type have it's own formatter?
    dataHasTableFormatter = cellfun(@(c) isa(c, 'nansen.metadata.tablevar.mixin.HasTableColumnFormatter'), firstRowData);
    formattingFcn(dataHasTableFormatter) = cellfun(@(c) ...
        str2func(class(eval( strjoin({class(c), 'TableColumnFormatter'}, '.')))), ...
        firstRowData(dataHasTableFormatter), 'uni', 0);

    % Step 4: Format all the table columns that needs formatting

    % Convert table to struct for the formatting of values.
    % (Can't change the datatype of the table columns otherwise...?)
    tempStruct = table2struct(T);
    numRows = numel(tempStruct);

    numCols = numel(formattingFcn);
    for jColumn = 1:numCols % Go through columns

        if isempty(formattingFcn{jColumn})
            continue
        end

        jColumnName = T.Properties.VariableNames{jColumn};
        jColumnValues = { tempStruct.(jColumnName) };
        thisFormatter = formattingFcn{jColumn};

        if isa( thisFormatter, 'char' )
            tmpFcn = str2func( thisFormatter );
            formattedValue = cellfun(@(s) tmpFcn(s), jColumnValues, 'uni', 0);
            if strcmp(thisFormatter, 'datetime')
                isEmpty = cellfun(@isempty, formattedValue);
                [formattedValue{isEmpty}] = deal(NaT);
            end

        elseif isa( thisFormatter, 'function_handle')
            try
                tmpObj = thisFormatter( jColumnValues );
                if isa(tmpObj, 'cell')
                    formattedValue = tmpObj;
                else
                    formattedValue = tmpObj.getCellDisplayString();
                end
            catch ME
                if contains(ME.message, 'rgb2hsv')
                    warning('Session table might not be rendered correctly. Try to restart Matlab, and if you still see this message, please report')
                else
                    warning('Failed to format data for display for table column "%s"', jColumnName)
                    disp(getReport(ME))
                end
                formattedValue = repmat({''}, numRows, 1);
            end
        else
            % This should not kick in
        end

        [tempStruct(:).(jColumnName)] = deal(formattedValue{:});
    end

    % Convert back to table.
    T = struct2table(tempStruct, 'AsArray', true);
end

function strVector = getCustomDisplayString(dataObj)
    strVector = cell(numel(dataObj), 1);
    for i = 1:numel(dataObj)
        rep = dataObj{i}.compactRepresentationForColumn();
        strVector{i} = rep.Representation;
    end
end
