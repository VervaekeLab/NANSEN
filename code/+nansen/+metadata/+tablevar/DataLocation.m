classdef DataLocation < nansen.metadata.abstract.TableVariable
    
    
   properties
       % Value is a struct of pathstrings pointing to data locations.
       % Each field is a key representing the datatype, i.e rawdata or
       % processed etc, and each value is an individual char/string or a
       % cell array of chars/strings if one data are present in
       % multiple locations.
       Value struct
   
   end
   
   methods
        function obj = DataLocation(S)
            obj@nansen.metadata.abstract.TableVariable(S);
        end
    end
   
   
    methods
        function str = getCellDisplayString(obj)
            str = '';
        end
       
        function str = getCellTooltipString(obj)
            str = '';
        end
       
   end
    
    
end