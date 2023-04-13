classdef MultiLocationDataSet < nansen.dataio.DataSet
    
    % Representation of a dataset with data in multiple locations. 
    % I.e for different types of raw data in one location, processed data
    % in another location and results in a third, etc.
    %
    %   This is already baked into the DataLocationModel, but this class
    %   could be a way to formalize it better?
    
    properties
        DataLocationModel
        VariableModel
    end
    
end