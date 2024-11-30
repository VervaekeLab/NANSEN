classdef NoteBook
%NOTEBOOK A collection of notes
    %   Detailed explanation goes here
    
    % Note: Under construction...
    
    properties (Dependent, SetAccess = private)
        NumNotes
    end
    
    properties
        DefaultDateDisplayFormat = 'yyyy.MM.dd'
        DefaultTimeDisplayFormat = 'HH:mm:ss'
        DefaultDateTimeDisplayFormat = 'dd-MMM-yyyy - HH:mm:ss'
    end
    
    properties (Access = private)
        NoteArray   % Struct array or array of note objects
    end
    
    methods
        
        function obj = NoteBook(notes)
            %NOTEBOOK Construct an instance of this class
            %   Detailed explanation goes here
            
            if isa(notes, 'struct')
                notes = nansen.notes.Note(notes);
            end
            
            obj.NoteArray = notes;
        end
    end
    
    methods
        function numNotes = get.NumNotes(obj)
            numNotes = numel(obj.NoteArray);
        end
        
        function addNote(obj)
            
        end
        
        function removeNote(obj)
            
        end
    end
    
    methods
        
        function noteArray = getNoteArray(obj, noteIdx)
            noteArray = obj.NoteArray(noteIdx);
        end
        
        function tags = getAllTags(obj)
            
            tags = unique([ obj.NoteArray.Tags ]);
            
        end
        
        function strCellArray = getFormattedDate(obj, datetimeFormat)
            
            noteDateCreated = [obj.NoteArray.DateTime];
            noteDateCreated.Format = datetimeFormat;
            
            strCellArray = char(noteDateCreated);
        
        end
        
        function titleStrArray = getTitleArray(obj)
            titleStrArray = {obj.NoteArray.Title};
        end
        
        function oidCellArray = getObjectIds(obj)
            oidCellArray = {obj.NoteArray.ObjectID};
        end
        
        function sortIdx = getSortIdx(obj, fieldName, sortDirection)
            %Todo: Implement more fieldnames...
            
            switch fieldName
                case {'DateCreated', 'DateTime'}
                    values = [obj.NoteArray.(fieldName)];
                    [~, sortIdx] = sort(values, sortDirection);
            end
        end

        function idx = getTypeMatch(obj, type)
            
            idx = find(strcmp({obj.NoteArray.Type}, type));
            
        end
        
        function idx = getTagMatch(obj, tag)
            
            idx = [];
            
            for i = 1:obj.NumNotes
                
                if any(strcmp(obj.NoteArray(i).Tags, tag))
                    idx = [idx, i];
                end
            end
        end
    end
end
