function out = titleCase(str, exceptions)
%TITLECASE Convert string to title case with lowercase exceptions
%
% out = utility.string.titleCase(str)
% out = utility.string.titleCase(str, exceptions)

    arguments
        str (1,1) string
        exceptions (1,:) string = [ ...
            "a","an","the", ...
            "and","but","or","nor","for","so","yet", ...
            "as","at","by","for","from","in","of","on","to","up","via","with"]
    end

    % Split into words
    words = split(lower(str));

    n = numel(words);

    for i = 1:n
        word = words(i);

        isFirst = (i == 1);
        isLast  = (i == n);

        if isFirst || isLast || ~any(word == exceptions)
            % Capitalize first letter
            words(i) = upper(extractBefore(word,2)) + extractAfter(word,1);
        end
    end

    % Join back into string
    out = join(words, " ");
end
