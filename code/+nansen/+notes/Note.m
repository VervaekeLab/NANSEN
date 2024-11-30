classdef Note
%NOTE Interface for a metadata note
    %   Detailed explanation goes here
    
    properties (Constant, Hidden) % Todo: Enumeration? Subclasses?
        VALID_NOTE_TYPES = {'Informal', 'Important', 'Todo', 'Question'}
    end
    
    properties
        
        Author char           % Author of note
        DateTime datetime     % Datetime value when note was created
        TimeStamp char        % Timestamp when note was created... (char)
        
        %DateCreated        % Todo: Important
        %DateEdited
        
        ObjectType            % What nansen metaobject type created the note
        ObjectID              % ID of nansen metaobject that created note
        
        Title                 % Note title
        Type                  % Note type
        Text                  % Note text
        
        Tags                  % Note tags
        
    end
    
    properties (Access = private)
        Attachment                  % File or data attachment. Not implemented yet
    end
    
    methods
        
        function obj = Note(varargin)
            %NOTE Construct an instance of this class
            %   Detailed explanation goes here
            
            if ~nargin
                return
            end
            
            if isa(varargin{1}, 'struct')
                obj = obj.fromStruct(varargin{1});
            else
                % Not implemented yet
            end
        end
    end
    
    methods
        
        function S = struct(obj)
        %struct Get a struct from a note instance.
            warning('off', 'MATLAB:structOnObject')
            
            S = builtin('struct', obj);
            S = rmfield(S, {'VALID_NOTE_TYPES', 'Attachment'});
        
            warning('on', 'MATLAB:structOnObject')

        end
        
        function str = getFormattedStr(obj)
            
        end
        
        function subTitleStrArray = getSubTitleArray(obj, varargin)
        %getSubTitleArray Get array of subtitles for notes
        %
        %   strArray = noteObj.getSubTitleArray(prop1, prop2, ..., propN)
        %   returns an array of concatenated strings for each of the
        %   properties specified as inputs..
        
            numNotes = numel(obj);
            subTitleStrArray = cell(1, numNotes);
            
            for iNote = 1:numNotes
                tempCell = cell(1, numel(varargin));
            
                for jField = 1:numel(varargin)
                    
                    tempCell{jField} = obj(iNote).(varargin{jField});
                    
                    if strcmp(varargin{jField}, 'DateTime')
                        tempCell{jField} = char(tempCell{jField});
                    end
                end
                
                subTitleStrArray{iNote} = strjoin(tempCell,  ' | ');

            end
        end
    end
    
    methods (Access = protected)
        
        function obj = fromStruct(obj, S)
        %fromStruct Get property values from fields of struct
        
            propNames = fieldnames(S);
            numNotes = numel(S);
            
            obj(numNotes) = nansen.notes.Note;
            
            for iNote = 1:numel(S)
                for jProp = 1:numel(propNames)
                    obj(iNote).(propNames{jProp}) = S(iNote).(propNames{jProp});
                end
            end
        end
    end
    
    methods (Static, Access = protected)
        
        function t = getTimeStamp()
            t = datetime();
        end
    end
    
    methods (Static)
        function tags = getTags(textStr)
            tags = regexp(textStr, '#(\w+)','tokens');
            tags = [ tags{:} ];
        end
        
        function noteObj = uiCreate(objectType, objectId)
        %uiCreate Create note based on user user input.
        %
        %   noteObj = uiCreate(objectType, objectId)
        %
        %   Opens a user dialog to get the following fields:
        %   Author, type, title and text.
        %
        %   Also, detects and fills in the Tags field.
            
            S = struct();
            S.Type = nansen.notes.Note.VALID_NOTE_TYPES{1};
            S.Type_ = nansen.notes.Note.VALID_NOTE_TYPES;
            S.Author = utility.system.getUserName();
            S.Title = '';

            S.Text = '';
            S.Text_ = struct('type', 'multilinechar');
            
            %hApp = structeditor.App(S,'LabelPosition', 'Over' );
            
            hNoteCreator = nansen.notes.UiCreateNote(S);
            uiwait(hNoteCreator.UIFigure)
            
            if isvalid(hNoteCreator)
                noteStruct = hNoteCreator.noteStruct;
                delete(hNoteCreator)
            else
                noteObj = nansen.notes.Note.empty; return
            end
            
            noteStruct.ObjectID = objectId;
            noteStruct.ObjectType = objectType;
                        
            % Create new noteobj
            noteObj = nansen.notes.Note.new(noteStruct);
            
        end
        
        function noteObj = new(noteStruct)
        %new Create new note
            
            noteStruct.DateTime = nansen.notes.Note.getTimeStamp;
            noteStruct.TimeStamp = char(noteStruct.DateTime);
            
            noteStruct.Tags = nansen.notes.Note.getTags(noteStruct.Text);
            
            noteObj = nansen.notes.Note(noteStruct);
            
        end
    end
end
