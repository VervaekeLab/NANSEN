function fileAdapter = getTimeseriesFileAdapter(filePath)
%GETTIMESERIESFILEADAPTER Get a timeseries file adapter for given file type
%   Detailed explanation goes here
    
    [~, ~, fileExtension] = fileparts(filePath);
    
    switch fileExtension
        case {'mat', '.mat'}
            fileAdapter = signalviewer.fileadapter.timeseries.Matfile();
            
        otherwise
            error('File adapter does not yet exist for files of type "%s"', ...
                fileExtension)
    end
    
    fileAdapter.Filename = filePath;

end
