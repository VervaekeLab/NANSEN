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
    
    data.option_presets = struct(...
        'name', {'Option 1', 'Option 2'}, ...
        'description', {'Description for Option 1', 'Description for Option 2'} ...
    );
    data.parameters = struct(...
        'name', {'Param1', 'Param2'}, ...
        'default_value', {'Value1', 'Value2'}, ...
        'description', {'Description 1', 'Description 2'} ...
    );
    
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
