function str = numbersymbol2expression(str)

%todo: rename to: numbersign2expression

numChars = numel(str);

% todo:
% what if there are variable numbers?


for i = numChars:-1:1

    searchStr = repmat('#', 1, i);
    replaceStr = ['\', sprintf('d{%d}', i)];
    
    str = strrep(str, searchStr, replaceStr);
    
end