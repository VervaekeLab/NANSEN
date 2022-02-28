function snakeCaseStr = camel2snake(camelCaseStr)
%camel2snake Convert camelcase to snakecase
%
%   snakeCaseStr = utility.string.camel2snake(camelCaseStr)

    capitalLetterStrIdx = regexp(camelCaseStr, '[A-Z, 1-9]');

    % Work from tail to head, since we are inserting underscores and 
    % changing the length of the string
    for i = fliplr(capitalLetterStrIdx) 
        if i ~= 1
            camelCaseStr = insertBefore(camelCaseStr, i , '_');
        end
    end

    snakeCaseStr = lower(camelCaseStr);

end

            
