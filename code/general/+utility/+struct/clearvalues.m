function Sout = clearvalues(Sin, useZero)
%CLEARVALUES Summary of this function goes here
    
    if nargin < 2
        useZero = false;
    end
    
    numElements = numel(Sin);
    fieldNames = fieldnames(Sin);
    
    Sout = Sin(1);
    
    for i = 1:numel(fieldNames)
        
        value = Sout.(fieldNames{i});
        
        switch class(value)
            case 'struct'
                newValue = struct.empty;
            case 'cell'
                newValue = {};
                
            case 'table'
                error('Not supported for structs containing tables')

            case {'timeseries', 'timetable'}
                error('Not supported for structs containing timeseries or timetables')
        
            otherwise
                try
                    if useZero
                        newValue = zeros(size(value), 'like', value);
                    else
                        newValue = cast([], 'like', value);
                    end
                catch
                    error('Could not clear value for field %s because datatype %s is not supported', fieldNames{i}, class(value))
                end
        end
        
        Sout.(fieldNames{i}) = newValue;
        
    end
    
    [Sout(1:numElements)] = deal(Sout);
    
end

