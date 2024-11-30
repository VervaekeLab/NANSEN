function isCamelCase = iscamelcase(varname)
    
    capLetterStrInd = regexp(varname, '[A-Z]');
    if any(capLetterStrInd > 1)
        isCamelCase = true;
    else
        isCamelCase = false;
    end
end
