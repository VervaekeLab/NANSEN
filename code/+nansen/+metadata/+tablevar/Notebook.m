classdef Notebook < nansen.metadata.abstract.TableVariable
    
    % Todo
    %   [ ] Adapt addEntry and removeEntry to work for this class
    %   implementation. Was taken from sessionInventory.
    %   [ ] Same for: editMessages, onEditNotesButtonPress
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = struct.empty
    end

    properties
        % Struct array containing note entries. Each note entry should have 
        % the following fields:
        %   timestamp   % Time when message was generated
        %   type        % Comment, warning
        %   title       % Title of message
        %   message     % Actual message
        
        % Value struct
        
    end
   
    methods
        function obj = Notebook(S)
            obj@nansen.metadata.abstract.TableVariable(S);
            assert(isstruct(obj.Value), 'Value must be a struct')
        end
    end
    
    
    methods % Implement abstract methods of superclass
       
        function str = getCellDisplayString(obj)
                        
            % Struct is wrapped in a cell. This was done because
            % structarrays are not compatible with tables as far as I could
            % figure out...
            
            commentStruct = obj.Value;
            
            if iscell(commentStruct)
                commentStruct = commentStruct{1};
            end
            
            if isempty(commentStruct)
                str = '0 Notes';
                return
            else
                msgLevel = {commentStruct.level};
                numComments = sum(contains(lower(msgLevel), 'comment'));
                numWarnings = sum(contains(lower(msgLevel), 'warning'));
            end
            
            str1 = sprintf('Comments (%d)', numComments);
            icon1 = '/Applications/MATLAB_R2017b.app/toolbox/matlab/uitools/private/icon_help_32.png';
            str1 = sprintf('<html><img src="file:%s" width="10" height="10"><font color="#000000">%s</font>', icon1, str1);
            
            str2 = sprintf('Warnings (%d)', numWarnings);    
            icon2 = '/Applications/MATLAB_R2017b.app/toolbox/matlab/uitools/private/icon_warn_32.png';
            str2 = sprintf('<html><img src="file:%s" width="10" height="10"><font color="#000000">%s</font>', icon2, str2);

            
            
            if numComments == 0 && numWarnings > 0
                formattedStr = sprintf('%s', str2);
            elseif numWarnings == 0 && numComments > 0
                formattedStr = sprintf('%s', str1);
            elseif numWarnings > 0 && numComments > 0
                formattedStr = sprintf('%s , %s', str2, str1);
            end
            
            
            str = formattedStr;
        end
       
        function str = getCellTooltipString(obj)
           
            noteStruct = obj.Value;
            
            if isempty(noteStruct)
                str = '';
            else
                
                %str = sprintf('<html>&nbsp;<b>%s</b>', sessionID);
                
                for j = 1:numel(noteStruct)
                    newLine1 = sprintf('<br>&nbsp; %d) %s (%s)', j, noteStruct(j).title, noteStruct(j).timestamp);
                    str = [str, newLine1]; %#ok<AGROW>
                    newLine2 = sprintf('<br>&nbsp; %s', noteStruct(j).message);
                    str = [str, newLine2]; %#ok<AGROW>
                end

            end
        end
        
    end
    
    
    methods
        
        function entry = addNote(entry, title, message, level)
            
            % Level: comment, warning
            
            if nargin < 4; level = 'comment'; end
            
            % Initialize note:
            note = struct();
            note.timestamp = datestr(now, 'yyyy.mm.dd - HH:MM:SS');
            note.level = lower(level);
            note.title = title;
            note.message = message;
            
            if isa(entry.Notes, 'cell')
                entry.Notes = entry.Notes{1};
            end
            
            % Add note to session inventory entry.
            if isempty(entry.Notes)
                entry.Notes = note;
            else
                entry.Notes(end+1) = note;
            end
            
            entry.Notes = {entry.Notes};
            
        end
        
        
        function entry = removeNote(entry)
            
        end
        
        function editMessages(obj, sid)
            
            thisRow = contains(obj.entries.(obj.IDNAME), sid);
            
            thisEntry = table2struct( obj.entries(thisRow, :),'ToScalar',true);   
            
            notes = thisEntry.Notes;
            if isa(notes, 'cell')
                notes = notes{1};
            end
            
                        
            % Specify figure position (Open in the middle of the screen)
            screenSize = get(0, 'ScreenSize');
            figSize = [350, 400];
            figLoc = screenSize(3:4)/2 - figSize/2;
            
            % Open a temporary figure window
            tmpF = figure('Visible', 'on', 'Position', [figLoc, figSize]);
            tmpF.NumberTitle = 'off';
            tmpF.Name = 'Edit Session Notes';
            tmpF.MenuBar = 'none';
            tmpF.Resize = 'off';
            tmpF.CloseRequestFcn = @(s, e, f) uiresume(tmpF);
  
            % Open a listWithButton widget for editing the list of commands
            % in the history log.
            
            % Todo: Add edit feature
            % Also, add view feature
            widgetH = uiw.widget.ListWithButtons('Parent', tmpF);
            widgetH.Position = [.01,.005, .98, .99];
            if isempty(notes)
                widgetH.Items = {};
                notes = struct('timestamp', {}, 'level', {}, 'title', {}, 'message', {});
            else
                widgetH.Items = {notes.title};
            end
            widgetH.Callback = @obj.onEditNotesButtonPress;
            widgetH.AllowEdit = false;            
            widgetH.ButtonLocation = 'right';
            widgetH.UserData.Notes = notes;

            % Wait for the temporary window to close and replace the
            % notes with the new list of notes from the widget.
            uiwait(tmpF)

            % Todo: update notes..
            
            notes = widgetH.UserData.Notes;
            
            thisEntry.Notes = {notes};
            obj.entries(thisRow, :) = struct2table(thisEntry, 'AsArray', true);
            
            delete(tmpF) % Close the temporary figure.

        end
        
        
        function onEditNotesButtonPress(obj, src, event)
            
            switch event.Interaction
                    
                case 'Delete' % Just remove item
                    src.Items(event.SelectedIndex) = [];
                    src.UserData.Notes(event.SelectedIndex) = [];
                    obj.isModified = true;

                case {'Add'} %, 'Edit'
                    
                    % Initialize note:
                                             
                    note = sbutil.inputNote();
                    note.timestamp = datestr(now, 'yyyy.mm.dd - HH:MM:SS');
                    note.level = lower(note.level);
                    
                    src.Items{end+1} = note.title;
                    src.UserData.Notes(end+1) = note;
                    obj.isModified = true;

            end
            
        end

        
        
    end
   
        
    
    
end