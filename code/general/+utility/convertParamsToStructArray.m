function [S, D] = convertParamsToStructArray(filepath)
%
% NOTE: This function depends on the parameters file strictly following the
% parameters template format.

    % % Test extension of file. Must be a mat-file (.m)
    [~, ~, ext] = fileparts(filepath);
    
    if isempty(ext)
        filepath = [filepath, '.m'];
    elseif ~strcmp(ext, '.m')
        error('File must be a matlab file')
    end
    
    % % Read m-file as character vector
    f = fileread(filepath);
    
    % % Allocate an empty struct array for collecting parameter attributes
    S = struct(...
        'Name', {}, ...
        'DefaultValue', {}, ...
        'Description', {}, ...
        'ValidationMsg', {}, ...
        'ValidationFcn', {});

    
    % % Get names, default values and descriptons:
    fSub = getFileSectionStr(f, 1); % Get first subsection (local function)

    varBeginInd = strfind(fSub, 'P.'); % All parameter names should be succeeded by this expression
    

    for i = 1:numel(varBeginInd)
        
        % Isolate substring for current parameter by finding next newline
        strBegin = varBeginInd(i);
        strEnd = strBegin + regexp(fSub(strBegin:end), '\n', 'once');
        thisLine = fSub(strBegin:strEnd);
        
        % Split substring at = and % (Name = DefaltValue % Decription)
        subStringB = strsplit(thisLine, '%'); % Split out comment first
        subStringA = strsplit(subStringB{1}, '='); % Split first part @ =
        
        thisLineDivided = [subStringA, subStringB{2}];
        thisLineDivided = strtrim(thisLineDivided);
        
        % Make sure that this line was divided in three parts.
        msg = 'Parameter definition function does not adhere to required format';
        assert(numel(thisLineDivided)==3, msg)
        
        % Isolate relevant parts of substrings and add as attribtutes. This
        % might need more work, to take care of unwanted character symbols
        S(i).Name = strrep(thisLineDivided{1}, 'P.', '');
        S(i).DefaultValue = eval( strrep(thisLineDivided{2}, ';', ''));
        S(i).Description = thisLineDivided{3};
                
    end
    
    % % Get validation function and message
    fSub = getFileSectionStr(f, 2); % Get second subsection (local function)
    varBeginInd = strfind(fSub, 'V.'); % All parameter names should be succeeded by this expression    
    
    
    for i = 1:numel(varBeginInd)
        
        % Isolate current substring. Find semicolon -> newline (may have spaces inbetween)
        strBegin = varBeginInd(i);
        strEnd = strBegin + regexp(fSub(strBegin:end), '; *\n','once');  % {';\n', '; *\n'}
        thisLine = fSub(strBegin:strEnd);

        % Split substring at = sign.
        thisLineDivided = strsplit(thisLine, '=');
        
        % Get name and make sure that it matches the name at current index
        thisName = strrep( strtrim(thisLineDivided{1}), 'V.', '' );
        %msg = 'Names of P struct and V struct does not correspond';
        %assert(strcmp(S(i).Name, thisName), msg)
        
        isMatch = strcmpi({S.Name}, thisName);
        
        % Need to combine and split again, because string expressions in
        % the validation function might contain == characters...
        thisLineRemaining = strrep(thisLine, [thisLineDivided{1}, '='], '');
        thisLineDivided = strsplit(thisLineRemaining, '...');
        thisLineDivided = strtrim(thisLineDivided);
        
        validMsgStr = cleanValidationMessageStr( thisLineDivided{2} );
        
        S(isMatch).ValidationMsg = eval(validMsgStr);
        S(isMatch).ValidationFcn = eval(thisLineRemaining);

    end
    
    if nargout == 2
        D = getDescription(f);
    end
    
end

function strOut = cleanValidationMessageStr(strIn)

    strOut = regexprep( strIn, {')', ';', '\n'}, '');
    
end

function fOut = getFileSectionStr(fIn, sectionNumber)
    
    expr = cell(1,4);

    % % Get sections of file
    expr{1} = 'Specify parameters and default values';
    expr{2} = 'Specify customization flags';
    expr{3} = 'Specify validation/assertion test for each parameter';
    expr{4} = 'Adapt output to how many outputs are requested';

    % Take care of scenario where no customization section exists...
    if isempty(regexp(fIn, expr{2}, 'once'))
        expr{2} = expr{3};
    end
    
    switch sectionNumber
        case 1
            exprA = expr{1};
            exprB = expr{2};

        case 2
            exprA = expr{3};
            exprB = expr{4};
    end
    
    sectionBeg = strfind(fIn, exprA);
    sectionEnd = strfind(fIn, exprB);
    
    fOut = fIn(sectionBeg:sectionEnd);

end

function D = getDescription(f)
    
    % Get description from file string
    D = ''; % Todo
    
end


% % function strOut = cleanValidationFunctionString(strIn)
% % 
% %     strIn = fliplr(strIn);
% %     strIn = regexprep(strIn, ',', '', 'once');
% %     strOut = fliplr ( strIn );
% % 
% % end
