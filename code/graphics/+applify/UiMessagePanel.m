classdef UiMessagePanel < handle %& uiw.mixin.AssignPVPairs
    
    properties (Dependent)
        Position
    end
    
    properties
        LabelString = 'Message Window'
    end
    
    properties (Access = private)
        Parent
        UILabel
        UIListBox
        Position_ (1,4) double = [100 100 100 74];
    end
    
    methods
        
        function obj = UiMessagePanel(hParent, varargin)
            
            obj.Parent = hParent;
            obj.assignPVPairs(varargin{:})
            
            obj.createListbox()
            
            if ~isempty(obj.LabelString)
                obj.createListboxLabel()
            end
        end
        
        function printMessage(obj, msg, mode)
        %printMessage Print a message in the app's message window
        %
        %    obj.printMessage(msgString, mode) where msgString is a string 
        %    containing a message and mode is 'normal', 'append' or 'replace'.   
        %
        %        'normal'  : add new message
        %        'append'  : add message to end of current message
        %        'replace' : replace current message

            if nargin < 3; mode = 'normal'; end

            switch mode
                case 'normal'
                    obj.UIListBox.Items{end+1} = msg;
                case 'append'
                    newMessage = strcat(obj.UIListBox.Items{end}, ' ', msg);
                    obj.UIListBox.Items{end} = newMessage;
                case 'replace'
                    obj.UIListBox.Items{end} = msg;
            end

            drawnow
            scroll(obj.UIListBox, 'bottom')
            drawnow
        end

    end
    
    methods % Set / get
        
        function set.Position(obj, newValue)
            obj.Position_ = newValue;
            if ~isempty(obj.UIListBox)
                obj.UIListBox.Position = newValue;
                obj.updateLabelPosition()
            end
        end
        function pos = get.Position(obj)
            pos = obj.Position_;
        end
        
    end
    
    methods (Access = private)
        
        function assignPVPairs(obj, varargin)
            
            names = varargin(1:2:end);
            allNamesIsChar = all( cellfun(@(c) ischar(c), names) );
            assert(allNamesIsChar, 'Name-value pairs must come in pairs')
            
            value = varargin(2:2:end);
            
            for i = 1:numel(names)
                if isprop(obj, names{i})
                    obj.(names{i}) = value{i};
                else
                    fprintf('%s is not a property of this class\n.', names{i})
                end
            end
            
            
        end
        
        function createListboxLabel(obj)
            % Create MessageWindowListBoxLabel
            obj.UILabel = uilabel(obj.Parent);
            obj.UILabel.HorizontalAlignment = 'left';
            obj.UILabel.Text = obj.LabelString;
            obj.updateLabelPosition()
        end
        
        function createListbox(obj)
            % Create MessageWindowListBox
            obj.UIListBox = uilistbox(obj.Parent);
            obj.UIListBox.Position = obj.Position_;
            obj.UIListBox.Items = {};
            obj.UIListBox.Value = {};
            
            %obj.UIListBox.Scrollable = 'on'; % necessary?

        end
        
        function updateLabelPosition(obj)
            if ~isempty(obj.UILabel)
                position = obj.UILabel.Position;
                position(1) = obj.UIListBox.Position(1) - 5;
                position(2) = obj.UIListBox.Position(2) + ...
                    obj.UIListBox.Position(4) + 2;
                position(3) = 100;
                obj.UILabel.Position = position;
            end
        end
        
    end
    
end