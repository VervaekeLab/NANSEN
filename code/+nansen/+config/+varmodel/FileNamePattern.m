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

        function assertValid(expression)
        %assertValid - Error when an expression has unknown placeholders
        %   assertValid(EXPRESSION) throws an error that names the unknown
        %   placeholders and lists the valid ones.
            import nansen.config.varmodel.FileNamePattern

            names = listPlaceholderNames(expression); % Local function
            isUnknown = ~ismember(names, {FileNamePattern.Placeholders.Name});

            if any(isUnknown)
                unknownList = strjoin( strcat('{', names(isUnknown), '}'), ', ' );
                validList = strjoin( strcat('{', {FileNamePattern.Placeholders.Name}, '}'), ', ' );
                error('NANSEN:VariableModel:UnknownPlaceholder', ...
                    ['The file name expression "%s" has an unknown placeholder: %s. ', ...
                    'Use one of the following: %s'], char(expression), unknownList, validList)
            end
        end

        function tf = canExpand(expression, values)
        %canExpand - True when every placeholder has a value
        %   TF = canExpand(EXPRESSION,VALUES) is true when every placeholder
        %   in EXPRESSION is known and has a non-empty field in the struct
        %   VALUES.
            import nansen.config.varmodel.FileNamePattern

            names = listPlaceholderNames(expression); % Local function

            tf = all( ismember(names, {FileNamePattern.Placeholders.Name}) );
            for i = 1:numel(names)
                tf = tf && isfield(values, names{i}) && ~isempty(values.(names{i}));
            end
        end

        function expanded = expand(expression, values)
        %expand - Replace the placeholders with their values
        %   EXPANDED = expand(EXPRESSION,VALUES) replaces each placeholder
        %   in EXPRESSION with the field of the same name in the struct
        %   VALUES. A placeholder whose field is missing or empty is an
        %   error, and so is an unknown placeholder.
            import nansen.config.varmodel.FileNamePattern

            FileNamePattern.assertValid(expression)
            expanded = char(expression);

            names = listPlaceholderNames(expression); % Local function

            for i = 1:numel(names)
                if ~isfield(values, names{i}) || isempty(values.(names{i}))
                    error('NANSEN:VariableModel:MissingPlaceholderValue', ...
                        'No value is available for the placeholder {%s} in "%s"', ...
                        names{i}, char(expression))
                end
                replacement = char( string(values.(names{i})) );
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
