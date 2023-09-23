function parameterStruct = getScanParameters(fileRef, parameterList)
%getScanParameters Get scan parameters for scanimage recording
%
%GETSCANPARAMETERS Summary of this function goes here
%   Detailed explanation goes here
    
    import nansen.module.ophys.twophoton.utility.scanimage.getParameterValueFromString
    
    if isa(fileRef, 'char') && isfile(fileRef)
        [~, ~, ext] = fileparts(fileRef);
        
        if strcmpi(ext, '.tif') || strcmpi(ext, '.tiff')
            tiffObj = Tiff(fileRef);
        else
            error('Files of type "%s" are not implemented', ext)
        end
    elseif isa(fileRef, 'char') && strncmp(fileRef, 'SI', 2)
        infoString = fileRef;
        
    elseif isa(fileRef, 'Tiff')
        tiffObj = fileRef;
    else
        error('Unsupported input.')
    end
    
    if exist('tiffObj', 'var')
        infoString = tiffObj.getTag('Software');
    end
    
    if ~exist('infoString', 'var')
        error(['ScanImage file information was not detected from input. ', ...
               'Please make sure input is a filepath or a Tiff object for a ', ...
               'valid ScanImage file or the Software tag of the tiff file'] );
    end
    
    if ~isa(parameterList, 'cell')
        parameterList = {parameterList};
    end
    
    % Detect part of string containing variables we want.
    infoFieldsCell = transpose( strsplit(infoString, newline) );
    matchIdx = contains(infoFieldsCell, parameterList) ;
    infoFieldsCell = infoFieldsCell(matchIdx);
    
    parameterStruct = struct;

    % Loop through parameters and assign values to output struct
    for i = 1:numel(parameterList)
        
        % Get item which matches current variable name
        varname = parameterList{i};
        isMatch = contains(infoFieldsCell, varname);
        
        if ~any(isMatch)
            warning('Parameter with name "%s" was not found');
        elseif any(isMatch)
            matchedStr = infoFieldsCell{isMatch};
            
            % Convert name to substruct:
            names = strsplit(varname, '.');
            subsCell = cat(1, repmat({'.'}, 1, numel(names)), names);
            subs = substruct(subsCell{:});
            
            % Get parameter value from string
            paramValue = getParameterValueFromString(matchedStr);
            
            parameterStruct = subsasgn(parameterStruct, subs, paramValue);
        end
    end

end