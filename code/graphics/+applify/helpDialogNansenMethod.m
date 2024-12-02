function helpDialogNansenMethod(functionName, options)

    arguments
        functionName (1,1) string
        options.Title (1,1) string = functionName
    end

    % Extract description

    titleStr = sprintf('%s - Nansen Method Help', options.Title);
    functionNameSplit = split(functionName, '.');

    functionFilepath = which(functionName);
    [summary, description] = extractDocString(functionFilepath);
    
    data.title = titleStr;
    data.main_title = titleStr;
    data.helptext = char(summary);
    data.helptopic = functionNameSplit{end};
    data.description = char(description);
    
    data.parameters = struct.empty;
    
    optionsManager = nansen.OptionsManager(functionName);
    data.option_presets = optionsManager.getPresetMetadata();

    if strcmp(optionsManager.FunctionType,'Function')
        data.parameters = optionsManager.getOptionDescriptions();
    else
        S = optionsManager.getDefaultOptions;
        data.parameters = flattenNestedStruct(S);
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
        summary = docstringLines{1};
        description = docstringLines(2:end);
        description( strtrim(description) == "" ) = [];
        description = strjoin(description, newline);
    end
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
            flatStruct(end).description = 'not available yet.';
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

