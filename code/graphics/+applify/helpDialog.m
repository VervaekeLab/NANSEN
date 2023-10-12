function helpDialog(functionName)

    functionNameSplit = strsplit(functionName, '.');
    functionNameShort = functionNameSplit{end};

    theme = nansen.theme.getThemeColors('light');

    functionFilepath = which(functionName);
    functionContentStr = fileread(functionFilepath);
    
    [idx, functions] = regexp(functionContentStr, 'function.*?end', 'start', 'match');
    
    function_def = functions{1};
    function_def = regexprep(function_def, '\n        ', '', 'once');
        
    functionLines = strsplit(function_def, '\n', 'CollapseDelimiters', false);

    functionDoc = {};

    for i = 2:numel(functionLines)
        if strncmp(functionLines{i}, '%', 1)
            functionDoc{end+1} = strrep( functionLines{i}, '%', '');
            if i == 2
                functionDoc{end} = strrep( functionDoc{end}, functionNameShort, '');
                functionDoc{end} = strrep( functionDoc{end}, upper(functionNameShort), '');
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
    helpfig.Name = sprintf('Help for %s', functionName);

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

        count = count + 1;
        hTxt(count) = text(0.05, y, sprintf(messages{i}));

        if makeBold; hTxt(count).FontWeight = 'bold'; end

        y = y + 0.04;
    end
    
    hTxt = hTxt(1:count);
    
    color = theme.FigureFgColor;
    set(hTxt, 'FontSize', 14, 'Color', color, 'VerticalAlignment', 'top')

    % Adjust size of figure to wrap around text.
    % txtUnits = get(hTxt(1), 'Units');
    set(hTxt, 'Units', 'pixel')
    extent = cell2mat(get(hTxt, 'Extent'));
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