classdef FileNamePattern
%FileNamePattern - Placeholders in data variable file name expressions
%   The FileNameExpression of a data variable may contain placeholders
%   that are replaced with session metadata when a file is located or
%   named. A placeholder is a name in curly braces, such as {sessionID}.
%
%   An expression with a placeholder names the whole file name without
%   its extension, and * stands for any characters. An expression
%   without a placeholder is a part of the file name, as before.
%
%   FileNamePattern functions:
%       listPlaceholders - List the placeholders and what they stand for
%       hasPlaceholder   - True when an expression contains a placeholder
%       isValid          - True when every placeholder in an expression is known
%       assertValid      - Error when an expression has unknown placeholders
%       canExpand        - True when every placeholder has a value
%       expand           - Replace the placeholders with their values
%       toFileName       - Append the file extension to an expanded expression
%       toRegexp         - Regular expression matching an expanded file name
%
%   See also VariableModel

    properties (Constant)
        % Placeholder names, each the name of the session property that
        % supplies its value, with a description for user interfaces
        Placeholders = struct( ...
            'Name', {'sessionID', 'subjectID'}, ...
            'Description', {'The session ID', 'The subject ID'})
    end

    methods (Static)

        function placeholders = listPlaceholders()
        %listPlaceholders - List the placeholders and what they stand for
        %   placeholders = listPlaceholders() returns a struct array with
        %   the fields Name and Description, one element per placeholder.
            placeholders = nansen.config.varmodel.FileNamePattern.Placeholders;
        end

        function tf = hasPlaceholder(expression)
        %hasPlaceholder - True when an expression contains a placeholder
        %   TF = hasPlaceholder(EXPRESSION) is true when EXPRESSION contains
        %   a name in curly braces, whether or not the name is known.
            tf = ~isempty(regexp(char(expression), '\{\w+\}', 'once'));
        end

        function [tf, message] = isValid(expression)
        %isValid - True when every placeholder in an expression is known
        %   TF = isValid(EXPRESSION) is true when every name in curly braces
        %   in EXPRESSION is a placeholder that listPlaceholders returns. An
        %   expression without placeholders is valid.
        %
        %   [TF,MESSAGE] = isValid(EXPRESSION) also returns a message that
        %   names the unknown placeholders and lists the valid ones, or ''
        %   when TF is true.

            arguments
                expression (1,:) char
            end

            import nansen.config.varmodel.FileNamePattern

            validNames = {FileNamePattern.Placeholders.Name};
            names = listPlaceholderNames(expression); % Local function
            isUnknown = ~ismember(names, validNames);

            tf = ~any(isUnknown);
            message = '';

            if ~tf
                unknownList = strjoin( strcat('{', names(isUnknown), '}'), ', ' );
                validList = strjoin( strcat('{', validNames, '}'), ', ' );
                message = sprintf(['The file name expression "%s" has an unknown ', ...
                    'placeholder: %s. Use one of the following: %s.'], ...
                    expression, unknownList, validList);
            end
        end

        function assertValid(expression)
        %assertValid - Error when an expression has unknown placeholders
        %   assertValid(EXPRESSION) throws an error that names the unknown
        %   placeholders and lists the valid ones.

            arguments
                expression (1,:) char
            end

            [tf, message] = nansen.config.varmodel.FileNamePattern.isValid(expression);
            if ~tf
                error("NANSEN:VariableModel:UnknownPlaceholder", "%s", message)
            end
        end

        function [tf, message] = canExpand(expression, values)
        %canExpand - True when every placeholder has a value
        %   TF = canExpand(EXPRESSION,VALUES) is true when every placeholder
        %   in EXPRESSION is known and has a value in the struct VALUES. A
        %   value is the field of the same name, and it counts only when it
        %   converts to one string that is neither missing nor empty, so
        %   "", '', [], NaN and <missing> are not values.
        %
        %   [TF,MESSAGE] = canExpand(EXPRESSION,VALUES) also returns a
        %   message that names the unknown placeholders or the first
        %   placeholder without a value, or '' when TF is true.

            arguments
                expression (1,:) char
                values (1,1) struct
            end

            import nansen.config.varmodel.FileNamePattern

            [tf, message] = FileNamePattern.isValid(expression);
            if ~tf; return; end

            names = listPlaceholderNames(expression); % Local function
            hasValue = cellfun(@(name) ~ismissing(getPlaceholderText(values, name)), names);

            if ~all(hasValue)
                tf = false;
                name = names{find(~hasValue, 1)};
                message = sprintf(['The placeholder {%s} in the file name expression ', ...
                    '"%s" has no value. Set the %s of the session, or remove {%s} ', ...
                    'from the expression.'], name, expression, name, name);
            end
        end

        function expanded = expand(expression, values)
        %expand - Replace the placeholders with their values
        %   EXPANDED = expand(EXPRESSION,VALUES) replaces each placeholder
        %   in EXPRESSION with the field of the same name in the struct
        %   VALUES. An unknown placeholder is an error, and so is a
        %   placeholder without a value as canExpand defines it.

            arguments
                expression (1,:) char
                values (1,1) struct
            end

            import nansen.config.varmodel.FileNamePattern

            FileNamePattern.assertValid(expression)

            [isExpandable, message] = FileNamePattern.canExpand(expression, values);
            if ~isExpandable
                error("NANSEN:VariableModel:MissingPlaceholderValue", "%s", message)
            end

            expanded = expression;
            names = listPlaceholderNames(expression); % Local function

            for i = 1:numel(names)
                replacement = char( getPlaceholderText(values, names{i}) ); % Local function
                expanded = strrep(expanded, ['{', names{i}, '}'], replacement);
            end
        end

        function fileName = toFileName(expandedExpression, fileType)
        %toFileName - Append the file extension to an expanded expression
        %   fileName = toFileName(expandedExpression,fileType) appends
        %   fileType, with a leading dot, unless expandedExpression already
        %   ends with it.
            fileType = char(fileType);
            if ~isempty(fileType) && ~strncmp(fileType, '.', 1)
                fileType = ['.', fileType];
            end

            fileName = char(expandedExpression);
            if ~endsWith(fileName, fileType)
                fileName = [fileName, fileType];
            end
        end

        function pattern = toRegexp(fileName)
        %toRegexp - Regular expression matching an expanded file name
        %   PATTERN = toRegexp(fileName) matches the whole of fileName,
        %   where * stands for any characters.
            pattern = ['^', regexptranslate('wildcard', char(fileName)), '$'];
        end
    end
end

function names = listPlaceholderNames(expression)
%listPlaceholderNames - Distinct placeholder names in an expression
%   The result is a cell array of character vectors, empty when the
%   expression has no placeholder.
    tokens = regexp(char(expression), '\{(\w+)\}', 'tokens');
    names = cellfun(@(token) token{1}, tokens, 'UniformOutput', false);
    names = unique(names, 'stable');
end

function text = getPlaceholderText(values, name)
%getPlaceholderText - The text that replaces a placeholder
%   TEXT is the field NAME of the struct VALUES converted to a string. It
%   is <missing> when the field is absent, or when the value does not
%   convert to one string that is neither missing nor empty.

    arguments
        values (1,1) struct
        name (1,:) char
    end

    text = string(missing);

    if isfield(values, name)
        value = string(values.(name));
        if isscalar(value) && ~ismissing(value) && strlength(value) > 0
            text = value;
        end
    end
end
