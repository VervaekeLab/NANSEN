function result = strArrayToBulletList(strArray, options)

    arguments
        strArray (1,:) string
        options.BulletChar (1,1) string = "-"
        options.Indentation (1,1) double = 1
    end

    indentation = string( repmat(' ', 1, options.Indentation) );
    
    result = indentation + options.BulletChar + " " + strArray;
    result = strjoin(result, newline);
end
