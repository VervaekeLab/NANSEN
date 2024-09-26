classdef CatalogWithBackup < handle
% Mixin that backs up the Data property of a catalog.
%
%   Todo: implement on datalocationmodel, variablemodel etc.

    properties (Abstract, SetAccess = protected)
        Data         % Subclass should implement
    end
    
    properties (Dependent)
        IsDirty      % Flag indicating if Data property is dirty (modified)
    end

    properties (Access = private)
        DataOriginal % Stores the original Data
    end
    
    methods
        
        function originalData = getOriginalData(obj)
            originalData = obj.DataOriginal;
        end

        function isDirty = get.IsDirty(obj)
            isDirty = isequal(obj.Data, obj.DataOriginal);
        end

        function backupCurrentData(obj)
            obj.DataOriginal = obj.Data;
        end

        function restoreBackupData(obj)
            obj.Data = obj.DataOriginal;
        end

        function clearBackupData(obj)
            obj.DataOriginal = [];
        end
    end
end
