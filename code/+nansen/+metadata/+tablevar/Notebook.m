classdef Notebook < nansen.metadata.abstract.TableVariable & nansen.metadata.abstract.TableColumnFormatter
%Notebook A table variable implementation for a notebook variable.
%
%   See also nansen.metadata.abstract.TableVariable nansen.notes.Note
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = struct.empty
    end
   
    methods % Constructor
        
        function obj = Notebook(S)
            if nargin < 1; S = struct.empty; end
            obj@nansen.metadata.abstract.TableVariable(S);
            
            assert( all( arrayfun(@isstruct, [obj.Value])), 'Value must be a struct')
        end
        
    end
    
    methods % Implementation of abstract superclass methods
       
        function str = getCellDisplayString(obj)
                        
            % Struct is wrapped in a cell. This was done because
            % structarrays are not compatible with tables as far as I could
            % figure out...
            
            str = cell(1, numel(obj));
            
            for i = 1:numel(obj)
           
                commentStruct = obj(i).Value;
            
                if iscell(commentStruct)
                    commentStruct = commentStruct{1};
                end
            
                str{i} = sprintf('%d Notes', numel(commentStruct));

                if isempty(commentStruct)
                    continue
                else
    % %                 msgLevel = {commentStruct.Type};
    % %                 numComments = sum(contains(lower(msgLevel), 'informal'));
    % %                 numWarnings = sum(contains(lower(msgLevel), 'important'));
                end
            
            
                formattedStr = sprintf('<html><font color="#000000"> %s </font>', str{i});


                if contains('Informal', {commentStruct.Type})
                    iconHtmlStr = obj.getIconHtmlString('help');
                    formattedStr = strcat(formattedStr, iconHtmlStr);
                end

                if contains('Important', {commentStruct.Type})
                    iconHtmlStr = obj.getIconHtmlString('warn');
                    formattedStr = strcat(formattedStr, iconHtmlStr);
                end

                if contains('Question', {commentStruct.Type})
                    iconHtmlStr = obj.getIconHtmlString('quest');
                    formattedStr = strcat(formattedStr, iconHtmlStr);
                end

                if contains('Todo', {commentStruct.Type})
                    iconHtmlStr = obj.getIconHtmlString('error');
                    formattedStr = strcat(formattedStr, iconHtmlStr);
                end

            

% % %             if numComments == 0 && numWarnings > 0
% % %                 formattedStr = sprintf('<html><font color="#000000"> %s </font> %s', str, str2);
% % %             elseif numWarnings == 0 && numComments > 0
% % %                 formattedStr = sprintf('<html><font color="#000000"> %s </font> %s', str, str1);
% % %             elseif numWarnings > 0 && numComments > 0
% % %                 spaceStr = sprintf('<html><font color="#000000"> %s </font>', ' '); %todo... figure out how to make space between icons...
% % %                 formattedStr = sprintf('<html><font color="#000000"> %s </font> %s %s %s', str, str2, spaceStr, str1);
% % %             else
% % %                 
% % %             end
            
                str{i} = formattedStr;
            end
        end
       
        function str = getCellTooltipString(obj)
           
            noteStruct = obj.Value;
            
            if isempty(noteStruct)
                str = '';
            else
                
                str = sprintf('<html>&nbsp;<b>%s</b>', noteStruct(1).ObjectID);
                
                for j = 1:numel(noteStruct)
                    newLine1 = sprintf('<br>&nbsp; %d) %s (%s)', j, noteStruct(j).Title, noteStruct(j).TimeStamp);
                    str = [str, newLine1]; %#ok<AGROW>
                    newLine2 = sprintf('<br>&nbsp; %s', noteStruct(j).Text);
                    str = [str, newLine2]; %#ok<AGROW>
                end

            end
        end
        
        function onCellDoubleClick(obj, ~)
            if ~isempty(obj.Value)
                obj.openNotebookUI()
            end
        end
        
    end

    methods (Access = private)
        
        function openNotebookUI(obj)
        %openNotebookUI Open the notebook ui using this notebook instance.
            hApp = obj.getNotebookViewer();
            hApp.Visible = 'on';
            hApp.openNotebook(obj.Value);
        end
        
    end
        
    methods (Static)
        
        function hApp = getNotebookViewer()
        %getNotebookViewer Get notebook viewer from global variable.
        %
        %   Get notebook viewer from a global variable. If the global
        %   variable is empty, create a new notebook viewer.

            global NoteBookViewer
            
            if isempty(NoteBookViewer) || ~isvalid(NoteBookViewer)
                NoteBookViewer = nansen.notes.NoteViewerApp();
                NoteBookViewer.setClosePolicy('hide')
            end
            
            hApp = NoteBookViewer;
            
        end
        
        function str = getIconHtmlString(iconName)
            
            % Todo: Create better icons and place in nansen...

            %warn, error, quest, help
            iconPath = sprintf( '/Applications/MATLAB_R2017b.app/toolbox/matlab/uitools/private/icon_%s_32.png', iconName);
            str = sprintf('<img src="file:%s" width="10" height="10" margin="0">', iconPath);
            
        end
        
    end
    
    
end