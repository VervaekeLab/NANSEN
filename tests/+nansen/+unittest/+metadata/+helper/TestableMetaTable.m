classdef TestableMetaTable < nansen.metadata.MetaTable
    % TestableMetaTable - A MetaTable subclass for unit testing
    %
    %   This subclass exposes methods to set properties that have
    %   restricted SetAccess in the parent class, allowing tests to
    %   configure MetaTable instances without requiring complex setup.
    
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
