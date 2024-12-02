function helpDialog(functionName, options)

    arguments
        functionName (1,1) string
        options.Title (1,1) string = functionName
    end

    if endsWith(functionName, 'Quicky')
        functionFilepath = which(functionName);

        htmlFilepath = replace(functionFilepath, ...
            '+sessionmethod/+process/+autoSegmentation/Quicky.m', ...
            'resources/documentation/process/autoSegmentation/Quicky.html');
        web(htmlFilepath, '-new', '-notoolbar')
        return
    end

    sectionHeaders = [...
        "Summary", ...
        "Description", ...
        "Option Presets", ...
        "Parameters"];

    functionNameSplit = strsplit(functionName, '.');
    functionNameShort = functionNameSplit{end};

    theme = nansen.theme.getThemeColors('light');

    functionFilepath = which(functionName);
    functionContentStr = fileread(functionFilepath);
    
    [idx, functions] = regexp(functionContentStr, 'classdef.*?end', 'start', 'match');
    if isempty(idx)
        [idx, functions] = regexp(functionContentStr, 'function.*?end', 'start', 'match');
    end

    function_def = functions{1};
    function_def = regexprep(function_def, '\n        ', '', 'once');
        
    functionLines = strsplit(function_def, '\n', 'CollapseDelimiters', false);
    functionLines{1} = '% Summary:';
    functionDoc = {};

    for i = 1:numel(functionLines)
        if strncmp(functionLines{i}, '%', 1)
            functionDoc{end+1} = strrep( functionLines{i}, '%', '');
            if i == 2
                functionDoc{end} = regexprep( functionDoc{end}, functionNameShort, '', 'once', 'ignorecase');
            end
        else
            break
        end
    end
    
    % Create a figure for showing help text
    helpfig = figure('Position', [100,200,500,500], 'Visible', 'off');
    helpfig.Resize = 'off';
    helpfig.Color = theme.FigureBgColor;
    helpfig.MenuBar = 'none';
    helpfig.NumberTitle = 'off';
    helpfig.Name = sprintf('Help for %s', options.Title);

    % Create an axes to plot text in
    ax = axes('Parent', helpfig, 'Position', [0,0,1,1]);
    ax.Visible = 'off';
    hold on

    messages = functionDoc;

    % Plot messages from bottom top. split messages by colon and
    % put in different xpositions.
    numMessage = numel(messages);
    hTxt = gobjects(numMessage, 1);
    
    y = 0.1;
    x1 = 0.05;
    %x2 = 0.3;
    
    count = 0;

    for i = numel(messages):-1:1
        nLines = numel(strfind(messages{i}, '\n'));
        %y = y + nLines*0.03;

        makeBold = contains(messages{i}, '\b');
        messages{i} = strrep(messages{i}, '\b', '');

        if any(startsWith(strtrim(messages{i}), sectionHeaders))
            makeBold = true;
        end

        count = count + 1;
        hTxt(count) = text(0.05, y, sprintf(messages{i}));

        if makeBold; hTxt(count).FontWeight = 'bold'; end
        if startsWith(strtrim(messages{i}), 'https://')
            makeHyperlink(hTxt(count))
        end

        y = y + 0.04;
    end
    
    hTxt = hTxt(1:count);
    
    color = theme.FigureFgColor;
    set(hTxt, 'FontSize', 14, 'Color', color, 'VerticalAlignment', 'top')

    % Adjust size of figure to wrap around text.
    % txtUnits = get(hTxt(1), 'Units');
    set(hTxt, 'Units', 'pixel')

    extent = get(hTxt, 'Extent');
    if iscell(extent)
        extent = cell2mat(extent);
    end

    % set(hTxt, 'Units', txtUnits)

    maxWidth = max(sum(extent(:, [1,3]),2));
    helpfig.Position(3) = max([550, maxWidth./0.9]); %helpfig.Position(3)*0.1 + maxWidth;
    helpfig.Position(4) = helpfig.Position(4) - (1-y)*helpfig.Position(4);
    uim.utility.centerFigureOnScreen(helpfig)
    helpfig.Visible = 'on';
    
    warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
    
    % Close help window if it loses focus
    jframe = getjframe(helpfig);
    set(jframe, 'WindowDeactivatedCallback', @(s, e) delete(helpfig))
    
    warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
end

function makeHyperlink(hText)

    hText.Color = 'blue';
    hText.FontWeight = 'bold';
    hText.Interpreter = 'none';
    
    % Add an interactive callback to simulate a hyperlink
    set(hText, 'ButtonDownFcn', @(src, event) web(hText.String, '-browser'));
    
    % Make the text object clickable
    hText.HitTest = 'on';
    
    % Set the axes to allow clicking on the text
    % set(gca, 'ButtonDownFcn', []);
end