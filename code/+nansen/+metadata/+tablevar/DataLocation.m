classdef DataLocation < nansen.metadata.abstract.TableVariable
    
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = struct.empty
    end

    
    properties
        % Value is a struct of pathstrings pointing to data locations.
        % Each field is a key representing the datatype, i.e rawdata or
        % processed etc, and each value is an individual char/string or a
        % cell array of chars/strings if one data are present in
        % multiple locations.

        % Value struct
    end
   
    methods
        function obj = DataLocation(S)
            obj@nansen.metadata.abstract.TableVariable(S);
            assert(isstruct(obj.Value), 'Value must be a struct')
        end
    end
   
   
    methods
        function str = getCellDisplayString(obj)
            numDataLocations = numel(fieldnames(obj.Value));
            str = sprintf('%d Datalocations', numDataLocations);
        end
       
        function str = getCellTooltipString(obj)
            
            datalocStruct = obj.Value;
            
            if isa(datalocStruct, 'cell')
                datalocStruct = datalocStruct{1};
            end
            
            if isempty(datalocStruct)
                str = '';
            else
                % Format struct into a multiline string:
                structStr = evalc('disp(datalocStruct)');
                
                while true % Remove trailing newlines...
                    if strcmp(structStr(end),  sprintf('\n'))                   %#ok<SPRINTFN>
                        structStr(end)='';
                    else
                        break
                    end
                end
                structStr = strrep(structStr, sprintf('\n'), '<br />');         %#ok<SPRINTFN>
                
                % This is hanging around from previous implementation.
                % structStr = [sprintf('<b>%s:</b> <br />', metaVar.sessionID{1}), structStr];
                
                % Align all lines to the right, i.e justify at the : sign 
                % since all struct values are same length (0 or 1).
                str = sprintf('<html><div align="left"> %s </div>', structStr);
                                
            end
        end
       
        function value = update(obj, sessionObj)
                  
            value = obj.Value;
            
            global dataLocationModel % Todo: dont use global
            if isempty(dataLocationModel)
                dataLocationModel = nansen.setup.model.DataLocations();
            end
            
            for i = 1:numel(dataLocationModel.Data)
                thisLoc = dataLocationModel.Data(i);
                pathString = sessionObj.detectSessionFolder(thisLoc);
                if ~isempty(pathString)
                    value.(thisLoc) = pathString; 
                end
            end
            
        end
   end
    
    
end