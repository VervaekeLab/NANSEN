classdef MetaTableFake < nansen.metadata.MetaTable
%MetaTableFake Minimal MetaTable subclass for unit testing
%
%   Exposes methods to set properties that have restricted SetAccess in the
%   parent class, allowing tests to configure MetaTable instances without
%   requiring a real file-backed project.
    
    methods
        function setFilepath(obj, filepath)
            % setFilepath - Set the filepath property (for testing only)
            obj.filepath = filepath;
        end
        
        function setEntries(obj, entries)
            % setEntries - Set the entries property (for testing only)
            obj.entries = entries;
        end
    end
end
