function infoString = getTiffSoftwareTagAsString(fileRef)
%getTiffSoftwareTagAsString Get the software tag from tiff file reference
%
%   infoString = getTiffSoftwareTagAsString(fileRef) returns the software
%   tag as a string for a tiff file given a fileRef. The fileRef can be a
%   file path to a tiff file or a Tiff object.

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
end
