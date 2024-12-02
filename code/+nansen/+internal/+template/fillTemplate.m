function renderedHTML = fillTemplate(templatePath, outputPath, data)
    % fillTemplate - Populates a template with data and writes the output to a file.
    %
    % Syntax: renderedHTML = fillTemplate(templatePath, outputPath, data)
    %
    % Inputs:
    %    templatePath - Path to the template file (string)
    %    outputPath   - Path to save the rendered HTML output (string)
    %    data         - Struct containing data to populate the template
    %
    % Outputs:
    %    renderedHTML - Rendered HTML as a string
    
    % Read the template file
    template = fileread(templatePath);
    
    % Replace top-level fields
    fields = fieldnames(data);
    for i = 1:numel(fields)
        if ~isstruct(data.(fields{i})) && ~iscell(data.(fields{i}))
            placeholder = sprintf('{{ %s }}', fields{i});
            template = strrep(template, placeholder, string(data.(fields{i})));
        end
    end
    
    % Process repeating sections for option presets
    if isfield(data, 'option_presets')
        template = processForLoop(template, 'option_presets', data.option_presets);
    end

    % Process repeating sections for parameters
    if isfield(data, 'parameters')
        template = processForLoop(template, 'parameters', data.parameters);
    end
    
    % Write the rendered HTML to the output file
    renderedHTML = template;
    fid = fopen(outputPath, 'w');
    if fid == -1
        error('Unable to open output file: %s', outputPath);
    end
    fprintf(fid, '%s', renderedHTML);
    fclose(fid);
end

function template = processForLoop(template, sectionName, loopParams)
    % processForLoop - Replaces a for-loop section in the template with repeated items
    %
    % Inputs:
    %    template    - Template string
    %    sectionName - Section name in the template
    %    dataList    - Struct array containing the data
    %    itemTemplate - Template for individual items
    %
    % Output:
    %    template    - Updated template string
    
    template = char(template);
    template_lines = splitlines(template);
    trimmed_lines = strtrim(template_lines);

    % Define loop directive placeholders
    startPlaceholder = sprintf('{%% for .* %s %%}', sectionName);
    endPlaceholder = sprintf('{%% endfor %%}');
    
    % Locate the loop section
    lineMatch = regexp(trimmed_lines, startPlaceholder, 'once');
    startIdx = find(cellfun(@(c) ~isempty(c), lineMatch));
    lineMatch = regexp(trimmed_lines(startIdx:end), endPlaceholder, 'once');
    endIdx = find(cellfun(@(c) ~isempty(c), lineMatch), 1, 'first') + startIdx - 1;

    if isempty(startIdx) || isempty(endIdx)
        return; % No loop section found
    end
    
    % Extract everything between the loop directives
    loopContent = template_lines(startIdx+1:endIdx-1);
    loopContent = strjoin(loopContent, newline);

    placeholderPattern = '\{\{\s*([a-zA-Z0-9_\.]+)\s*\}\}';
    % Extract unique placeholders
    tokens = regexp(loopContent, placeholderPattern, 'tokens');
    tokens = string(tokens);
    placeholders = compose('{{ %s }}', tokens);

    loopTemplate = regexprep(loopContent, placeholders, '%s');

    % Filter loopParams by detected tokens:
    A = squeeze( split(tokens, '.') );
    fieldNames = A(:,2);
    allFieldNames = fieldnames(loopParams);
    loopParams = rmfield(loopParams, setdiff(fieldNames, allFieldNames));
    loopParams = orderfields(loopParams, fieldNames);

    strValues = squeeze( string( struct2cell(loopParams) ))';

    % Build array of replace values for compose
    loopContentFinal = compose(loopTemplate, strValues);
    loopContentFinal = strjoin(loopContentFinal, newline);
    
    % Replace the loop section in the template
    template = strjoin( cat(1, ...
        template_lines(1:startIdx-1), ...
        loopContentFinal, ...
        template_lines(endIdx+1:end)), newline );
end
