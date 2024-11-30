classdef FolderPathViewer < applify.HasTheme
%FolderPathViewer Show a list of folderpaths in a table
%
% See also nansen.config.dloc.FolderOrganizationUI

%   Todo:
%       [ ] Add a refresh button
%       [ ] Add togglebutton for table view and list view
%       [ ] Develop table view. Number, FolderA, FolderB etc, relative path, absolute path
%

    properties (Constant, Hidden = true)
        DEFAULT_THEME = nansen.theme.getThemeColors('deepblue')
    end
    
    properties (Dependent)
        Data
        Visible
    end

    properties (Access = private)
        Figure
        UITable
        UIPanelHeader
        UILabelHeader
    end
    
    properties (Access = private)
        ReferenceFigure     % Figure of app which created object
    end
    
    methods
        
        function obj = FolderPathViewer(refFigure)
        %FolderPathViewer Constructor
        
            if nargin == 1
                obj.ReferenceFigure = refFigure;
            end
            
            obj.createFigure()
            obj.createTable()

            obj.createHeader()
            
            obj.onThemeChanged()
            obj.Visible = 'on';
            
        end
        
        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure)
            end
        end
    end
    
    methods % Set/get methods
        function set.Visible(obj, newValue)
            validationMsg = 'Value must be on or off';
            newValue = validatestring(newValue, {'on', 'off'}, validationMsg);
            obj.Figure.Visible = newValue;
            if strcmp(newValue, 'on')
                obj.placeFigure()
            end
        end
        function value = get.Visible(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                value = obj.Figure.Visible;
            else
                value = 'off';
            end
        end
        
        function set.Data(obj, newValue)
            if isrow(newValue); newValue = transpose(newValue); end
            obj.UITable.Data = newValue;
        end
        function data = get.Data(obj)
            data = obj.UITable.Data;
        end
    end
    
    methods (Access = private)
        
        function createFigure(obj)
            
            obj.Figure = figure('Visible', 'off');
            obj.Figure.Name = 'Detected data folders';
            obj.Figure.MenuBar = 'none';
            obj.Figure.NumberTitle = 'off';
            obj.Figure.SizeChangedFcn = @(s,e) obj.updateContainerPositions;
                        
            obj.placeFigure()
            
            obj.Figure.DeleteFcn = @(s,e) obj.delete;
            
        end
        
        function createHeader(obj)
        %createHeader Create a header for the viewer
        
            % Create panel for displaying info text...
            obj.UIPanelHeader = uipanel(obj.Figure);
            %obj.HeaderPanel.BorderType = 'none';
            obj.UIPanelHeader.Units = 'pixels';

            msg = ['Shows a list of all folders that are found using the ', ...
                   'current folder organization settings.'];

            % Create control for displaying info text.
            obj.UILabelHeader = uicontrol(obj.UIPanelHeader, 'style', 'text');
            obj.UILabelHeader.String = msg;
            obj.UILabelHeader.Position = [10, 10, obj.UIPanelHeader.Position(3:4)-20];
            obj.UILabelHeader.FontSize = 14;
            
        end
        
        function createTable(obj)
        %createTable Create UI Table for showing list of folderpaths
        
            tableParams = { ...
                'Parent', obj.Figure, ...
                'Theme', uim.style.tableLightNansen, ...
                'ShowColumnHeader', false, ...
                'ColumnResizePolicy', 'next' };

            % Create table using the StylableTable
            obj.UITable = uim.widget.StylableTable( tableParams{:} );
            
            obj.UITable.Units = 'pixels';
            obj.UITable.FontName = 'helvetica';
            obj.UITable.FontSize = 9;
            obj.UITable.ColumnName = {'Detected data folders'};
            
        end
        
        function placeFigure(obj)
        %placeFigure Place figure on screen
            
            if isempty(obj.ReferenceFigure); return; end
            
            % Calculate position for placement of new figure
                        
            % Get size of current monitor...
            screenSize = uim.utility.getCurrentScreenSize(obj.ReferenceFigure);
            
            % ... and place figure to the right of the reference figure
            referencePosition = obj.ReferenceFigure.Position;
            newFigPosition = referencePosition;
            newFigPosition(1) = sum( referencePosition([1,3]) ) + 10;                  % Why 10??? % Todo (UI4)
            newFigPosition(3) = screenSize(3) - referencePosition(3) - 30;             % Why 30??? % Todo (UI4)
                      
            newFigPosition(4) = min([600, obj.Figure.Position(4)]);
            newFigPosition(2) = screenSize(2) + screenSize(4)/2 - newFigPosition(4)/2;
            
            obj.Figure.Position = newFigPosition;
        end
        
        function updateContainerPositions(obj)
        %updateContainerPositions Update positions of ui components
        
            figureSize = obj.Figure.Position(3:4);
            
            % Set position of table
            obj.UITable.Position = [20, 20, figureSize - [40, 60]];
            
            % Set position of header panel.
            height = 63;
            obj.UIPanelHeader.Position = [1, figureSize(2)-height, ...
                                          figureSize(1), height];
                                      
            % Set position of header label.
            obj.UILabelHeader.Position = [10, 10, obj.UIPanelHeader.Position(3:4)-20];

        end
    end
    
    methods (Access = protected)
        
        function onThemeChanged(obj)
        %onThemeChanged Callback for value change on Theme property
        %
        %   % Set colors for components.
        
            obj.Figure.Color = obj.Theme.FigureBgColor;
            
            obj.UIPanelHeader.BackgroundColor = obj.Theme.HeaderBgColor;

            obj.UILabelHeader.BackgroundColor = obj.Theme.HeaderBgColor;
            obj.UILabelHeader.ForegroundColor = obj.Theme.HeaderFgColor;
        end
        
        function onVisibleChanged(obj)
            obj.Figure.Visible = obj.Visible;
        end
    end
end
