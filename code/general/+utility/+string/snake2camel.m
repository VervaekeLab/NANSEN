function camelCaseStr = snake2camel(snakeCaseStr)
%snake2camel Convert snakecase to camelcase
%
%   snakeCaseStr = utility.string.camel2snake(camelCaseStr)

    capitalLetterStrIdx = regexp(snakeCaseStr, '_');
    capitalLetterStrIdx = capitalLetterStrIdx + 1;
    
    for i = capitalLetterStrIdx
        snakeCaseStr(i) = upper(snakeCaseStr(i));
    end

    camelCaseStr = strrep(snakeCaseStr, '_', '');
end
