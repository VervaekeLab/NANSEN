classdef BaseSchema < uim.mixin.structAdapter
%BaseSchema Basis class for a metadata object definition.
%
% Properties are metadata info.
%
% Using a class makes it possible to use validation.
% Convert to/from struct
% Convert to/from table
% 
% A MetaTable is a table of metadata objects which must derive from this
% BaseSchema class.
%
% Todo: Clarify this..
% When a metadata object is picked from the table it is transformed to an
% object. The object provides methods for updating/plotting
%
%   See also MetaTable

%   Todo
%       [ ] Add methods for interacting with a metatable?


    properties (Abstract, Constant, Hidden)
        ANCESTOR
        IDNAME
    end
    
    properties (Constant, Hidden)
        
    end
    
    properties %(Abstract)
        Notebook = struct.empty        % struct
    end
    
    
    methods
        
        
        function fromStruct(obj, S)
            
            numObjects = numel(S);
            propertyNames = fieldnames(S);
            
            for i = 1:numObjects
                for j = 1:numel(propertyNames)
                    if isprop(obj, propertyNames{j})
                        obj(i).(propertyNames{j}) = S(i).(propertyNames{j});
                    end
                end
            end
            
            
        end
        
        
        function S = toStruct(obj)
        %TOSTRUCT Convert object to a struct. Skip Notebook property.
        %
        % Todo: Why do we skip the Notebook??     
            
            S = toStruct@uim.mixin.structAdapter(obj);
            %S = rmfield(S, 'Notebook');
            
        end

        
        function T = makeTable(obj)
            
            for i = 1:numel(obj)
                if i == 1
                    S = obj(i).toStruct();
                else
                    S(i) = obj(i).toStruct();
                end
            end
            
            T = struct2table(S, 'AsArray', true);
            
        end
        
        function fromTable(obj, dataTable)
           
            S = table2struct(dataTable);
            numObjects = numel(S);
            obj(numObjects).Notebook = struct.empty;
            obj.fromStruct(S);
            
        end
        
    end
    
end