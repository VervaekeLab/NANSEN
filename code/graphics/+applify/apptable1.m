classdef apptable1 < applify.UiControlTable
% A row based table for placing in an app using uifigure
%   
%   Work in progress. Adapting the apptable to version using uim-controls    
%
% Note1: Position only supported in pixels.
%
%   
% One question I have. Should I implement it as a superclass with abstract
% properties so that any implementation needs to go through a subclass or 
% should I make it possible to instantiate directly? For now,
% subclassing...

%
%   Todo:   
%       [x] Create method createTableRowComponents (which will be a subclass method)
%       [ ] Implement row checkbox as a true/false selection option
%       [ ] Come up with a nice way to add/remove columns. Ie dropbox
%           papers table. Or add toolbar buttons above table and checkboxes
%           for selecting  rows.
%       [x] place tablepanel right underneatch the column header border,
%           without spacing, but do something so that the interior area of
%           the scrollpanel is a bit higher than the uppermost component.
%

    properties
        ICONS = uim.style.iconSet(applify.apptable1.getIconPath)
    end


    properties % Table info/data
        ContainerAxes
        HeaderAxes
        TableAxes    % Axes object to plot labels, images and other components into.
    end

    
    methods % Structors
        
        function obj = apptable1(varargin)
        %apptable Constructor                
            
            obj@applify.UiControlTable(varargin{:})
                        

        end
        
        function delete(obj)
            
        end
    end

    
    methods (Access = protected) % Configuration and construction
        
        function assignDefaultTablePropertyValues(obj)
            % Subclasses may override this method.
        end
        
        function createTableRowComponents(obj) % defined in applify.UiControlTable
        
        end
        
        
        function createLayoutContainers(obj)
        %createLayoutContainers Create container objects based on layout
        	
            obj.createTablePanel() % Maybe this should be part of superclass constructor....
            
            % create axes for header and table
            uicc = uim.UIComponentCanvas(obj.Parent);
            obj.HeaderAxes = uicc.Axes;
            
            uicc = uim.UIComponentCanvas(obj.TablePanel);
            obj.TableAxes = uicc.Axes;
        
        end

        function openNewFigure(obj)
            obj.Parent = figure('MenuBar', 'none');
        end

        function createTempAxes(obj)
        % Temporary axes for getting length of strings to fit component 
        % width to text length..... Wtf matlab, this should not be necessary.
        
            obj.TempAxes = uiaxes(obj.Parent);
            obj.TempText = text(obj.TempAxes);
            obj.TempText.Units = 'pixel';
        end
        
        function createHeader(obj)
        %createHeader Create column header
        %
        %   Creates column labels, add border between column header and
        %   table and add help button on column headers if requested.
            
            % Create a border below the column header
            
            pos = obj.ColumnHeaderPosition;
            xData = [pos(1), pos(1)+pos(3)];
            yData = [pos(2), pos(2)];

            obj.ColumnHeaderBorder = plot(obj.HeaderAxes, xData, yData);
            obj.ColumnHeaderBorder.LineWidth = 1;
            obj.ColumnHeaderBorder.Color = obj.TableBorderColor;
            
            yOff = 5; % Correction factor in pixels to keep labels closer 
                      % to horizontal border below
                      
            % Todo(?): Create panel for header
            for i = 1:obj.NumColumns

                if isempty(obj.ColumnNames{i}) % Skip rest if column name is empty
                    continue
                end
                
                % Add position(1) to correct for xOffset (column header is 
                % created directly in parent, but table components are 
                % created in table panel)
                xi = obj.ColumnLocations(i) + obj.Position(1); 
                w = obj.ColumnWidths(i);
                y = obj.ColumnHeaderPosition(2) + 4;
                
                
                obj.ColumnHeaderLabels{i} = text(obj.HeaderAxes, xi, y+1, '');
                obj.ColumnHeaderLabels{i}.FontName = obj.FontName;
                obj.ColumnHeaderLabels{i}.FontWeight = 'bold';
                obj.ColumnHeaderLabels{i}.FontSize = 12;

                obj.ColumnHeaderLabels{i}.String = obj.ColumnNames{i};
                obj.ColumnHeaderLabels{i}.VerticalAlignment = 'bottom';
                
                extent = obj.ColumnHeaderLabels{i}.Extent; %obj.ColumnHeaderLabels{i}.Position;
                obj.ColumnHeaderLabels{i}.UserData.Extent = extent;
                
                %obj.ColumnHeaderLabels{i}.Position = [xi y w 22];
                %obj.centerComponent(obj.ColumnHeaderLabels{i}, y)
                
                if obj.ShowColumnHeaderHelp
                    
                    w_ = obj.ColumnHeaderLabels{i}.UserData.Extent(3);
                    btnPosition = [xi+w_+5, y, 18, 18];
                    
                    btnOptions = {'PositionMode', 'manual', ...
                        'SizeMode', 'manual', 'Position', btnPosition, ...
                        'Icon', obj.ICONS.help4, 'Size', btnPosition(3:4), ...
                        'Style', uim.style.helpButton};
                    
                                        
                    obj.ColumnLabelHelpButton{i} = uim.control.Button_(obj.Parent, btnOptions{:});
                    obj.ColumnLabelHelpButton{i}.Callback = @obj.onHelpButtonClicked;
                    %obj.ColumnLabelHelpButton{i}.Tag = obj.ColumnNames{i};
                    %obj.centerComponent(obj.ColumnLabelHelpButton{i}, y-yOff)
                end
                
            end
            
            % Add horizontal border below header.
            
        end
        
        function centerComponent(obj, hComponent, yPos)
            
            yHeight = obj.RowHeight + obj.RowSpacing;
            
            try
                yOffset = ( yHeight - hComponent.Position(4) ) / 2;
            catch
                yOffset = ( yHeight - hComponent.Extent(4) ) / 2;
            end
            hComponent.Position(2) = yPos + yOffset;
            
        end
        
        function onHelpButtonClicked(obj, src, ~)
        %onHelpButtonClicked Show help message using uialert
        
            if isempty(obj.ColumnHeaderHelpFcn);    return;     end
        
            hFigure = ancestor(obj.Parent, 'figure');
            
            msg = obj.ColumnHeaderHelpFcn(src.Tag);
            title = sprintf('Help for %s', src.Tag);
            %uialert(hFigure, msg, title, 'Icon', 'info')
            disp(msg)
        end
        
        function setTableScrolling(obj, state)
            msg = 'Table scroll state must be ''on'' or ''off''';
            assert( any( strcmp(state, {'on', 'off'}) ), msg)
            obj.TablePanel.Scrollable = state;
        end

%         function createTableRow(obj, rowNum)
%             
%             % y = obj.RowLocations(rowNum);
% 
%         end

    end
    
    
    methods (Static)
        function pathStr = getIconPath()
            rootPath = fileparts( mfilename('fullpath') );
            pathStr = fullfile(rootPath, '_graphics', 'icons');
        end
    end
    
end