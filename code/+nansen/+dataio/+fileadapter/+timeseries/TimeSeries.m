classdef TimeSeries < nansen.dataio.FileAdapter
%TimeSeries File adapter for a file that can be opened as an timeseries   
    

    properties (Constant)
        DataType = 'timeseries'
    end
    
    properties (Constant, Hidden, Access = protected)
        SUPPORTED_FILE_TYPES = {'mat'}
    end
    
    
    methods (Access = protected)
        
        function tsObj = readData(obj, varargin)
            
            % Todo: Varargin might specify variables...
            
            S = load(obj.Filename, varargin{:});
            varNames = fieldnames(dataS);
            
            if isempty(varNames)
                error('No variables were loaded for file "%s"', obj.Name)
            end
            
            tsObj = cell(1, numel(varNames));
            % Create timeseries objects...
            for i = 1:numel(varNames)
                tsObj{i} = timeseries( S.(varNames{i}), 'Name', varNames{i} );
            end
            tsObj = cat(1, tsObj{:});
            
        end
        
        function writeData(obj, data, varName)
            
            if isa(data, 'timeseries')
                % Todo....
            end
            
            S.(varName) = data;
            
            if isfile(obj.Filename)
                save(obj.Filename, '-struct', 'S', '-append')
            else
                save(obj.Filename, '-struct', 'S')
            end
            
            
        end

    end
    
    methods
        
        function open(obj)
            
        end
        
        function view(obj)
            signalviewer.App(ts);
        end
        
    end
    
    methods 

    end
    
end