    function foldedStr = foldStr(str, preferredWidth)
    
    str = char(str);
    if nargin < 2
        preferredWidth = 200;
    end
    
    nCharsPerLine = preferredWidth;
    
    % Start loop where message is split on spaces to create lines
    % that will not exceed the width of the textbox. Loop finished
    % when it has gone over the whole message. Note: Messages are
    % also split on file separator, so that long pathstrings are
    % also split
          
    % Todo: Improve/simplify code.
    
    tmpmsg = str;
    lines = {};
    finished = false;
    c = 1;
    while ~finished
        [split, M] = strsplit(tmpmsg, {filesep, ' '});
        M{end+1} = '';
        a = cumsum( arrayfun(@(i) numel(split{i}) + i-1, 1:numel(split) ) );
        b = a-nCharsPerLine;
        b(b>0) = [];
        [~, ind] = max(b);
    
        lines{end+1} = strjoin( cat(1, split(1:ind), M(1:ind)), '');
        tmpmsg = strjoin( cat(1, split(ind+1:end), M(ind+1:end)), '');
        c = c + 1;
        if isempty(char(tmpmsg)); finished = true; end
    end

    foldedStr = strjoin(lines, newline);
end
