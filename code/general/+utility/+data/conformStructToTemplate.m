function S = conformStructToTemplate(S, template)
%conformStructToTemplate Restore struct array shapes lost in a json round trip
%
%   Syntax:
%       S = utility.data.conformStructToTemplate(S, template) returns the
%       struct array S with the class, orientation and emptiness of every
%       field restored to match the corresponding field of template.
%
%   Input arguments:
%       S        - A struct array, cell array of scalar structs, or empty
%                  value, typically the output of jsondecode.
%       template - A scalar struct declaring the intended shape of each
%                  field, typically a catalog's blank item.
%
%   Output arguments:
%       S        - A row struct array conforming to the template.
%
%   jsondecode is lossy in ways that matter to code which round trips a
%   struct through json:
%       - struct arrays come back as columns rather than rows
%       - an empty cell array comes back as [] rather than {}
%       - a numeric row vector comes back as a column
%       - an array with one element is indistinguishable from a scalar
%       - an empty array loses the field names it used to carry
%   This function undoes all of those against a declared template. Fields
%   that the template does not declare, such as Uuid, are passed through
%   untouched so that this can be applied to items that carry more than
%   the blank item defines.
%
%   See also jsondecode, utility.data.StorableCatalog

    arguments
        S
        template (1,1) struct
    end

    if isempty(S)
        % An empty json array decodes to [] and loses the field names
        S = template;
        S(1) = [];
        return
    end

    if iscell(S)
        % A json array whose objects do not all carry the same keys decodes
        % to a cell of scalar structs, which cannot be concatenated until
        % every element has the same fields in the same order.
        S = concatenateItems(cellfun(@(item) conformItem(item, template), ...
            reshape(S, 1, []), 'UniformOutput', false), template);
        return
    end

    S = reshape(S, 1, []);

    % Assign field by field rather than element by element, so that a field
    % the stored items lack can be added across the whole array.
    for fieldName = fieldnames(template)'
        for i = 1:numel(S)
            if isfield(S, fieldName{1})
                S(i).(fieldName{1}) = conformValue( ...
                    S(i).(fieldName{1}), template.(fieldName{1}));
            else
                S(i).(fieldName{1}) = template.(fieldName{1});
            end
        end
    end
end

function item = conformItem(item, template)
%conformItem Conform one scalar struct, filling in fields it does not have

    for fieldName = fieldnames(template)'
        if isfield(item, fieldName{1})
            item.(fieldName{1}) = conformValue( ...
                item.(fieldName{1}), template.(fieldName{1}));
        else
            item.(fieldName{1}) = template.(fieldName{1});
        end
    end
end

function S = concatenateItems(items, template)
%concatenateItems Join scalar structs that may carry different extra fields

    fieldOrder = fieldnames(template);
    for i = 1:numel(items)
        fieldOrder = [fieldOrder; setdiff(fieldnames(items{i}), fieldOrder, 'stable')]; %#ok<AGROW>
    end

    for i = 1:numel(items)
        missingFields = setdiff(fieldOrder, fieldnames(items{i}), 'stable');
        for fieldName = missingFields'
            items{i}.(fieldName{1}) = [];
        end
        items{i} = orderfields(items{i}, fieldOrder);
    end

    S = [items{:}];
end

function value = conformValue(value, templateValue)
%conformValue Restore one field value to the class and shape of its template

    if iscell(templateValue)
        if isempty(value)
            value = {};
        elseif ischar(value)
            value = cellstr(value)';
        else
            value = reshape(value, 1, []);
        end

    elseif isstruct(templateValue)
        value = utility.data.conformStructToTemplate(value, scalarTemplate(templateValue));

    elseif ischar(templateValue)
        if isempty(value)
            value = '';
        elseif isstring(value)
            value = char(value);
        end

    elseif islogical(templateValue)
        if ~isempty(value)
            value = logical(value);
        end

    elseif isnumeric(templateValue)
        if ~isempty(value) && ~ischar(value)
            value = reshape(value, 1, []);
        end
    end
    % Any other class, such as an enumeration, is left for the owning
    % catalog to restore in its modifyStructOnLoad method.
end

function template = scalarTemplate(template)
%scalarTemplate Get a scalar template from a struct array that may be empty

    if isempty(template)
        fieldNames = fieldnames(template)';
        fieldValues = repmat({[]}, 1, numel(fieldNames));
        nameValuePairs = [fieldNames; fieldValues];
        template = struct(nameValuePairs{:});
    else
        template = template(1);
    end
end
