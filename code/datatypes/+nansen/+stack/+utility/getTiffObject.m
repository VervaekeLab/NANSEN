function tiffObject = getTiffObject(fileRef)
%getTiffObject Get a Tiff object from a file reference
%
%   tiffObject = getTiffObject(fileRef) returns a tiff object from a tiff
%   file reference. The file reference should be the file path to a tiff
%   file, but if the fileRef is already a Tiff object, this function
%   returns.

    if isa(fileRef, 'Tiff')
        tiffObject = fileRef;

    elseif isa(fileRef, 'char') && isfile(fileRef)
        [~, ~, ext] = fileparts(fileRef);
        
        if strcmpi(ext, '.tif') || strcmpi(ext, '.tiff')
            tiffObject = Tiff(fileRef);
        else
            error('Files of type "%s" are not implemented', ext)
        end
    elseif isa(fileRef, 'cell') && isfile(fileRef{1})
        [~, ~, ext] = fileparts(fileRef{1});
        if strcmpi(ext, '.tif') || strcmpi(ext, '.tiff')
            tiffObject = cellfun(@(filepath) Tiff(filepath), fileRef);
        else
            error('Files of type "%s" are not implemented', ext)
        end

    else
        error('Unsupported input.')
    end
end
