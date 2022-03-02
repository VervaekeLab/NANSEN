classdef UiCreateNote < matlab.apps.AppBase
%UiCreateNote Small app for creating notes.

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        SelectTypeDropDown   matlab.ui.control.DropDown
        EnterTextTextArea    matlab.ui.control.TextArea
        TitleEditFieldLabel  matlab.ui.control.Label
        TitleEditField       matlab.ui.control.EditField
        AuthorLabel          matlab.ui.control.Label
        AuthorEditField      matlab.ui.control.EditField
        SaveButton           matlab.ui.control.Button
        CancelButton         matlab.ui.control.Button
    end
    
    properties
        noteStruct
    end
    
    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = UiCreateNote(noteTemplate)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            %registerApp(app, app.UIFigure)

            if ~nargin
                noteTemplate = app.getDefaultTemplate();
            end
            
            app.updateComponentValues(noteTemplate)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            
            % Delete UIFigure when app is deleted
            if isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Callback function
        function EnterTextTextAreaValueChanged(app, event)
            value = app.EnterTextTextArea.Value;
            app.TitleEditField.Value = value{1};
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 497 290];
            app.UIFigure.Name = 'Create New Note';

            % Create SelectTypeDropDown
            app.SelectTypeDropDown = uidropdown(app.UIFigure);
            app.SelectTypeDropDown.Position = [25 249 77 22];

            % Create EnterTextTextArea
            app.EnterTextTextArea = uitextarea(app.UIFigure);
            app.EnterTextTextArea.Position = [25 54 450 170];

            % Create TitleEditFieldLabel
            app.TitleEditFieldLabel = uilabel(app.UIFigure);
            app.TitleEditFieldLabel.Position = [123 249 33 22];
            app.TitleEditFieldLabel.Text = 'Title:';

            % Create TitleEditField
            app.TitleEditField = uieditfield(app.UIFigure, 'text');
            app.TitleEditField.Tooltip = {'trst'};
            app.TitleEditField.Position = [158 249 156 22];

            % Create AuthorLabel
            app.AuthorLabel = uilabel(app.UIFigure);
            app.AuthorLabel.Position = [335 249 45 22];
            app.AuthorLabel.Text = 'Author:';

            % Create AuthorEditField
            app.AuthorEditField = uieditfield(app.UIFigure, 'text');
            app.AuthorEditField.Position = [382 249 93 22];

            % Create SaveButton
            app.SaveButton = uibutton(app.UIFigure, 'push');
            app.SaveButton.Position = [126 17 100 22];
            app.SaveButton.Text = 'Save';
            app.SaveButton.ButtonPushedFcn = @app.onSaveButtonPushed;
            
            % Create CancelButton
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.Position = [274 17 100 22];
            app.CancelButton.Text = 'Cancel';
            app.CancelButton.ButtonPushedFcn = @app.onCancelButtonPushed;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
        
        function updateComponentValues(app, noteTemplate)
         
            app.SelectTypeDropDown.Items = noteTemplate.Type_;
            app.SelectTypeDropDown.Value = noteTemplate.Type;
            
            app.AuthorEditField.Value = noteTemplate.Author;
            
        end
        
        function storeComponentValues(app)
            
            app.noteStruct.Author = app.AuthorEditField.Value;
            app.noteStruct.Title = app.TitleEditField.Value;
            app.noteStruct.Type = app.SelectTypeDropDown.Value;
            app.noteStruct.Text = strjoin( app.EnterTextTextArea.Value, newline );
            
        end
        
        function success = verifyComponentValues(app)
                        
            if isempty( app.noteStruct.Author )
                uialert(app.UIFigure, 'Please enter name of author', 'Information Missing', 'Icon', 'error')
                success = false;
            end
            
            if isempty( app.noteStruct.Title )
                uialert(app.UIFigure, 'Please enter title', 'Information Missing', 'Icon', 'error')
                success = false;
            end 
            
            if isempty( app.noteStruct.Text )
                
                selection = uiconfirm(app.UIFigure, 'Do you want to create a note without any text?', 'Confirm Save', 'Options', {'Yes', 'Cancel'});
                switch selection
                    case 'Yes'
                        success = true;
                    otherwise
                        success = false;
                end
                
            end
            
            success = true;
            
        end
        
    end

    methods (Access = protected)
        function onSaveButtonPushed(app, src, evt)
            app.storeComponentValues()
            wasSuccess = app.verifyComponentValues();
            
            if wasSuccess
                delete(app.UIFigure)
            end
        end
        
        function onCancelButtonPushed(app, src, evt)
            app.delete()
        end
        
    end
    
    methods (Static)
               
        function noteTemplate = getDefaultTemplate()
            noteTemplate = struct();
            noteTemplate.Type = nansen.notes.Note.VALID_NOTE_TYPES{1};
            noteTemplate.Type_ = nansen.notes.Note.VALID_NOTE_TYPES;
            noteTemplate.Author = '';
        end
         
    end
end