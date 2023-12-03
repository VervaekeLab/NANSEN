classdef DataLocationType < handle
%DataLocationType Enumeration of data location types for nansen package  
    
    enumeration
        RECORDED('recorded')
        PROCESSED('processed')
        CURATED('curated')
        TEMPORARY('temporary') % todo: remove?
    end
    
    properties (SetAccess=immutable)
        Name = ''
        Alias = ''
        Description char 
        Permission char
        AllowAsDefault logical
    end
    
    
    methods
        
        function obj = DataLocationType(typeName)
            
            obj.Name = lower( typeName );
            
            switch lower( typeName )
                case 'recorded'
                    obj.Permission = 'read';
                    obj.AllowAsDefault = false;
                    obj.Alias = 'raw data';
                    obj.Description = 'Recorded (raw) data are the result of measurements from experimental probes. Recorded data can only be read from, not written to';
                    
                case 'processed'
                    obj.Permission = 'write';
                    obj.AllowAsDefault = true;
                    obj.Description = 'Processed data results from doing operations on recorded data. Processed data can be read from and written to';
                
                case 'curated'
                    obj.Permission = 'write';
                    obj.AllowAsDefault = false;
                    obj.Description = 'Curated data are processed data that additionally should meet pre-defined criteria for data quality.';
                    
                case 'temporary'
                    obj.Permission = 'write';
                    obj.AllowAsDefault = false;
                    obj.Description = 'Temporary data are data which is stored temporarily during a processing step';
            
            end
        end
    end
end