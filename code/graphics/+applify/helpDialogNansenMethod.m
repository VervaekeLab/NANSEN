function helpDialogNansenMethod(functionName, options)

    arguments
        functionName (1,1) string
        options.Title (1,1) string = functionName
    end

    % Extract description

    titleStr = sprintf('%s', options.Title);
    functionNameSplit = split(functionName, '.');

    functionFilepath = which(functionName);
    [summary, description] = extractDocString(functionFilepath);

    data.title = titleStr;
    data.main_title = titleStr;
    data.helptext = char(formatInlineGuideText(summary));
    data.helptopic = functionNameSplit{end};
    data.description = char(formatGuideTextAsHtml(description));

    data.parameters = struct.empty;

    try
        optionsManager = nansen.OptionsManager(functionName);
        data.option_presets = optionsManager.getPresetMetadata();

        if strcmp(optionsManager.FunctionType,'Function')
            data.parameters = optionsManager.getOptionDescriptions();
        else
            S = optionsManager.getDefaultOptions;
            data.parameters = flattenNestedStruct(S);
        end
    catch ME
        data.option_presets = struct.empty;
        data.parameters = struct(...
            'name', 'Options unavailable', ...
            'default_value', '', ...
            'description', ME.message);
    end

    templateFile = fullfile(nansen.toolboxdir, 'resources', 'templates', 'session_method_help.html.template');
    htmlFolder = fullfile(tempdir, 'nansen-html');

    if ~isfolder(htmlFolder)
        mkdir(htmlFolder);
        nansen.internal.template.copyCss(htmlFolder)
    end
    htmlFilepath = fullfile(htmlFolder, join(functionNameSplit(end-2:end), "_") + ".html");
    nansen.internal.template.fillTemplate(templateFile, htmlFilepath, data);

    web(htmlFilepath, '-new', '-notoolbar')
end

function [summary, description] = extractDocString(filePath)

    summary = "No summary";
    description = "No description";

    functionContent = fileread(filePath);

    docstringLines = string.empty;

    functionLines = splitlines(functionContent);
    for i = 1:numel(functionLines)
        thisLine = strtrim(functionLines(i));
        if startsWith(thisLine, 'function') || startsWith(thisLine, 'classdef')
            continue
        elseif startsWith(thisLine, '%')
            thisLine = extractAfter(thisLine, '%');
            docstringLines(end+1) = thisLine; %#ok<AGROW>
        else
            break
        end
    end

    if ~isempty(docstringLines)
        summary = strtrim(docstringLines{1});
        description = trimEmptyEdgeLines(docstringLines(2:end));
        description = strjoin(description, newline);
    end
end

function lines = trimEmptyEdgeLines(lines)
    while ~isempty(lines) && strtrim(lines(1)) == ""
        lines(1) = [];
    end
    while ~isempty(lines) && strtrim(lines(end)) == ""
        lines(end) = [];
    end
end

function htmlText = formatGuideTextAsHtml(text)
    lines = splitlines(string(text));
    htmlLines = strings(0, 1);
    paragraphLines = strings(0, 1);
    listItemLines = strings(0, 1);
    isInList = false;

    for i = 1:numel(lines)
        rawLine = string(lines(i));
        line = strtrim(rawLine);

        if line == ""
            flushParagraph()
            flushListItem()
            closeList()
        elseif isRawHtmlLine(line)
            flushParagraph()
            flushListItem()
            closeList()
            htmlLines(end+1, 1) = line; %#ok<AGROW>
        elseif any(startsWith(line, ["- ", "* "]))
            flushParagraph()
            if ~isInList
                htmlLines(end+1, 1) = "<ul>"; %#ok<AGROW>
                isInList = true;
            end
            flushListItem()
            itemText = extractAfter(line, 2);
            listItemLines(end+1, 1) = itemText; %#ok<AGROW>
        elseif isInList && startsWith(rawLine, "  ")
            listItemLines(end+1, 1) = line; %#ok<AGROW>
        elseif isGuideHeading(line)
            flushParagraph()
            flushListItem()
            closeList()
            heading = extractBefore(line, strlength(line));
            htmlLines(end+1, 1) = "<h2>" + formatInlineGuideText(heading) + "</h2>"; %#ok<AGROW>
        else
            flushListItem()
            closeList()
            paragraphLines(end+1, 1) = line; %#ok<AGROW>
        end
    end

    flushParagraph()
    flushListItem()
    closeList()

    if isempty(htmlLines)
        htmlText = "<p>No guide text available.</p>";
    else
        htmlText = strjoin(htmlLines, newline);
    end

    function flushParagraph()
        if isempty(paragraphLines)
            return
        end
        paragraphText = strjoin(paragraphLines, " ");
        htmlLines(end+1, 1) = "<p>" + formatInlineGuideText(paragraphText) + "</p>";
        paragraphLines = strings(0, 1);
    end

    function flushListItem()
        if isempty(listItemLines)
            return
        end
        itemText = strjoin(listItemLines, " ");
        htmlLines(end+1, 1) = "<li>" + formatInlineGuideText(itemText) + "</li>"; %#ok<AGROW>
        listItemLines = strings(0, 1);
    end

    function closeList()
        if isInList
            htmlLines(end+1, 1) = "</ul>";
            isInList = false;
        end
    end
end

function tf = isGuideHeading(line)
    tf = endsWith(line, ":") && strlength(line) <= 80 && ~contains(line, "://");
end

function tf = isRawHtmlLine(line)
    htmlPrefixes = ["<p", "</p", "<ul", "</ul", "<ol", "</ol", "<li", ...
        "<h1", "<h2", "<h3", "<div", "</div", "<strong", "<em", "<br"];
    tf = any(startsWith(line, htmlPrefixes));
end

function htmlText = formatInlineGuideText(text)
    htmlText = escapeHtml(strtrim(string(text)));
    htmlText = regexprep(htmlText, '`([^`]+)`', '<code>$1</code>');
end

function htmlText = escapeHtml(text)
    htmlText = replace(text, "&", "&amp;");
    htmlText = replace(htmlText, "<", "&lt;");
    htmlText = replace(htmlText, ">", "&gt;");
end

function flatStruct = flattenNestedStruct(nestedStruct, parentName)
    % Recursively flattens a nested struct into a struct with 'name' and 'default_value'
    % where nested fields are joined with "."
    %
    % Inputs:
    %   nestedStruct - The nested struct to flatten
    %   parentName   - (Optional) The parent field name for recursion
    %
    % Outputs:
    %   flatStruct   - The resulting flat struct with fields 'name' and 'default_value'

    if nargin < 2
        parentName = '';
    end

    flatStruct = struct('name', {}, 'default_value', {}, 'description', {});
    fieldNames = fieldnames(nestedStruct);

    for i = 1:numel(fieldNames)
        if endsWith(fieldNames{i}, '_')
            continue
        end

        fieldName = fieldNames{i};
        fullName = fieldName;
        if ~isempty(parentName)
            fullName = sprintf('%s.%s', parentName, fieldName);
        end

        value = nestedStruct.(fieldName);
        if isstruct(value)
            % Recurse into nested structs
            nestedFlatStruct = flattenNestedStruct(value, fullName);
            flatStruct = [flatStruct, nestedFlatStruct];
        else
            if ischar(value)
                % pass
            elseif isempty(value)
                value = '';
            elseif isscalar(value)
                value = formatValueAsString(value);
            else
                if iscell(value)
                    value = cellfun(@(c) formatValueAsString(c), value, 'uni', false);
                    value = sprintf('{%s}', strjoin(value, ', '));
                else
                    value = arrayfun(@(c) formatValueAsString(c), value, 'uni', false);
                    value = sprintf('[%s]', strjoin(value, ', '));
                end
            end

            % Add field to flatStruct
            flatStruct(end + 1).name = fullName;
            flatStruct(end).default_value = value;
            flatStruct(end).description = 'No description available.';
        end
    end
end

function value = formatValueAsString(value)
    if isinteger(value)
        value = sprintf('%d', value);
    elseif isnumeric(value)
        value = sprintf('%.2f', value);
    elseif islogical(value)
        if value
            value = 'true';
        else
            value = 'false';
        end
    end
end
