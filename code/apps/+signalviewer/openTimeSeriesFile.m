function timeSeries = openTimeSeriesFile(filePath)
%openTimeSeriesFile Open a file and return data as timeseries.

    % Questions: 
    %    Return timetable?

    fileAdapter = signalviewer.getTimeseriesFileAdapter(filePath);
    timeSeries = fileAdapter.load();
    
end