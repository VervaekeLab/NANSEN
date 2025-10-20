classdef HasNotes < handle
% HasNotes - Mixin for adding notes to metadata types
    properties % Todo: SetAccess = nansen.util.StructAdapter
        Notebook = struct.empty
    end

    methods
        function addNote(obj, note)
            if isa(note, 'nansen.notes.Note')
                noteStruct = struct(note);
            elseif isa(note, 'struct')
                noteStruct = note;
            else
                error('Invalid input')
            end
            
            if isempty(obj.Notebook)
                obj.Notebook = noteStruct;
            else
                obj.Notebook(end+1) = noteStruct;
            end
            
            obj.onNotebookPropertySet()
        end

        function removeNote(obj, noteIndex) %#ok<INUSD>
            error('Not implemented yet')
        end
    end

    methods (Access = protected)
        function onNotebookPropertySet(~)
            % Subclasses may implement
        end
    end 
end
