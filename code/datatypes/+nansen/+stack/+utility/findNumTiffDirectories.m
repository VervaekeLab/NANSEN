function [numDirs, finished] = findNumTiffDirectories(tiffRef, dirNumInit, stepSize)
%findNumTiffDirectories Find number of IFDs in a tiff file.
%
%   <strong>DESCRIPTION:</strong>
%   Recursive search for number of image file directories (IFDs) in a tiff
%   file. Try to set number of directories, using an incremental approach, 
%   and when it fails, restart at last successful number with smaller 
%   incremental steps.
%
%   <strong>SYNTAX:</strong>
%   numDirs = findNumTiffDirectories(tiffFilePath) returns the number of
%   image file directories (IFDs) in tiff file at specified file path.
%
%   numDirs = findNumTiffDirectories(tiffObj) returns the number of
%   image file directories (IFDs) for given Tiff object.
%
%   numDirs = findNumTiffDirectories(tiffFilePath, numDirInit) will start
%   looking for number of directories above a certain number. Useful if it
%   is known that file contains at least a certain number of directories.
%   Default = 1.
%
%   numDirs = findNumTiffDirectories(tiffFilePath, numDirInit, stepSize)
%   additionally specifies the stepSize to use when looking for number of
%   directories. Default is 10000.


%   NOTE:
%   Seems like when the setDirectory method of TIFF fails with the 
%   'MATLAB:imagesci:Tiff:unableToChangeDir' error ID, current directory is
%   set to the last directory in the file. In this case, recursive search
%   is not necessary.

    
    if ischar(tiffRef) && isfile(tiffRef)
        [~, ~, ext] = fileparts(tiffRef);
        if strcmp(ext, '.tif') || strcmp(ext, '.tiff')
            tiffObj = Tiff(tiffRef);
        else
            error('First input must be the path to an existing tiff file.')
        end
    elseif isa(tiffRef, 'Tiff')
        tiffObj = tiffRef;
    else
        error('First input must be a Tiff object or the path to a tiff file')
    end
    
    
    if nargin < 2; dirNumInit = 1; end
    if nargin < 3; stepSize = 10000; end

    numDirs = dirNumInit;
    finished = false;
    
    while ~finished
        
        try
            tiffObj.setDirectory(numDirs);
            numDirs = numDirs + stepSize;
        catch ME

            switch ME.identifier
                case 'MATLAB:imagesci:Tiff:tagRetrievalFailed'
                    warning('Unexpected error, please report..')
                
                case 'MATLAB:imagesci:Tiff:unableToChangeDir'
                    numDirs = tiffObj.currentDirectory();
                    finished = tiffObj.lastDirectory();
                
                case 'MATLAB:imagesci:validate:argumentOutOfBounds'
                    dirNumInit = tiffObj.currentDirectory();
                    newStepSize = stepSize / 10;
                    [numDirs, finished] = findNumTiffDirectories(tiffObj, dirNumInit, newStepSize);
                
                otherwise
                    error('Could not determine number of tiff directories, please report...')
            end
        end
    end
    
    if nargout == 1
        clear finished
    end
end


