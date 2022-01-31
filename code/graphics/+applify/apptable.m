classdef apptable < applify.UiControlTable
% A row based table for placing in an app using uifigure
%
%
% Note1: Position only supported in pixels.
%
% Note2: Each row is created using appdesigner/uifigure controls, so it
% might not be efficient for large data tables, would not recommend for
% tables larger than 20 rows.

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
%       [ ] Debug why text extent of header labels change in some cases
%           after the drawnow command is executed...


    properties (Access = protected, Hidden) % Internal layout properties
        TempAxes % Axes used for determining extent of text labels.
        TempText % Text used for determining extent of text labels.
    end
    
    
    properties (Access = protected, Hidden) % Internal graphical properties
        TableHeaderSpacer % An empty image placed in top of table panel to create some padding in the top of a scrollpanel.
        ImageGraphicPaths struct = struct()
    end
    
    
    methods % Structors
        
        function obj = apptable(varargin)
        %apptable Constructor                
            obj@applify.UiControlTable(varargin{:})
            
            delete(obj.TempAxes)
            
            obj.addTablePanelMargin() % Quirk needed in scrollable uipanel...

        end
        
        function delete(obj)
            
            % delete all table image graphics...
            fNames = fieldnames(obj.ImageGraphicPaths);
            for i = 1:numel(fNames)
                if isfile(obj.ImageGraphicPaths.(fNames{i}))
                    delete(obj.ImageGraphicPaths.(fNames{i}))
                end
            end
            
            obj.deleteHeader()
            
        end
        
    end
    

    
    methods (Access = protected) % Configuration and construction
        
        function assignDefaultTablePropertyValues(obj)
            % Subclasses may override this method.
        end
        
        function createTableRowComponents(obj)      	% defined in applify.UiControlTable
        
        end
        
        function createLayoutContainers(obj)
        %createLayoutContainers Create container objects based on layout
        	obj.createTablePanel()
            obj.createTempAxes()
        end

        function openNewFigure(obj)
            obj.Parent = uifigure();
        end

        function createTempAxes(obj)
        % Temporary axes for getting length of strings to fit component 
        % width to text length..... Wtf matlab, this should not be necessary.
        
            obj.TempAxes = uiaxes(obj.Parent);
            obj.TempText = text(obj.TempAxes);
            obj.TempText.Units = 'pixel';
            drawnow
        end
        
        function createHeader(obj)
        %createHeader Create column header
        %
        %   Creates column labels, add border between column header and
        %   table and add help button on column headers if requested.
            
            % Create a border below the column header
            imagePathStr = obj.getColumnHeaderRowBorder();
            obj.ColumnHeaderBorder = uiimage(obj.Parent);
            obj.ColumnHeaderBorder.Position = obj.ColumnHeaderPosition;
            obj.ColumnHeaderBorder.ImageSource = imagePathStr;
            
% %             rootPath = fileparts( mfilename('fullpath') );
% %             imgPath = fullfile(rootPath, '_graphics', 'icons');

            rootPath = fileparts(nansen.rootpath);
            imgPath = fullfile(rootPath, 'setup', '_icons');
            
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
                y = obj.ColumnHeaderPosition(2);
                
                
                obj.ColumnHeaderLabels{i} = uilabel(obj.Parent);
                obj.ColumnHeaderLabels{i}.FontName = obj.FontName;
                obj.ColumnHeaderLabels{i}.FontWeight = 'bold';
                obj.ColumnHeaderLabels{i}.FontSize = 12;

                obj.ColumnHeaderLabels{i}.Text = obj.ColumnNames{i};
                
                obj.TempText.String = obj.ColumnNames{i};
                                
% % %                 if strcmp(obj.ColumnNames{i}, 'Data location type')
% % %                     disp(obj.TempText.Extent)
% % %                     disp(obj.TempText.Position)
% % %                 end
                
                obj.TempText.FontName = obj.ColumnHeaderLabels{i}.FontName;
                obj.TempText.FontWeight = 'bold';
                obj.TempText.FontSize = obj.ColumnHeaderLabels{i}.FontSize;
                
                
                
                extent = obj.TempText.Extent; %obj.ColumnHeaderLabels{i}.Position;
                
% % %                 if strcmp(obj.ColumnNames{i}, 'Data location type')
% % %                     drawnow
% % %                 end
% % %                 
% % %                 extent2 = obj.TempText.Extent; %obj.ColumnHeaderLabels{i}.Position;

                obj.ColumnHeaderLabels{i}.UserData.Extent = extent;
                obj.ColumnHeaderLabels{i}.Position = [xi y w 22];
                

% % %                 if strcmp(obj.ColumnNames{i}, 'Data location type')
% % %                     disp(extent)
% % %                     disp(extent2)
% % %                     
% % % % %                     f = figure;
% % % % %                     copyobj(obj.TempAxes, f)
% % % % %                     
% % % % %                     h = findobj(f, 'Type', 'text');
% % % % %                     h.Extent
% % %                     
% % %                 end
                
                obj.centerComponent(obj.ColumnHeaderLabels{i}, y-yOff)
                
                if obj.ShowColumnHeaderHelp
                    obj.ColumnLabelHelpButton{i} = uiimage(obj.Parent);
                    w_ = obj.ColumnHeaderLabels{i}.UserData.Extent(3);
                    obj.ColumnLabelHelpButton{i}.Position = [xi+w_, y, 18, 18];
                    obj.ColumnLabelHelpButton{i}.ImageSource = fullfile(imgPath, 'help.png');
                    obj.ColumnLabelHelpButton{i}.ImageClickedFcn = @obj.onHelpButtonClicked;
                    obj.ColumnLabelHelpButton{i}.Tag = obj.ColumnNames{i};
                    obj.ColumnLabelHelpButton{i}.Tooltip = 'Press for help';
                    obj.centerComponent(obj.ColumnLabelHelpButton{i}, y-yOff)
                    
                end
                
            end
            
            % Add horizontal border below header.
            
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

        function updateTableRowBackground(obj, rowNumber, isSelected)
                
            hRow = obj.RowControls(rowNumber);
            
            if isSelected
                selection = 'on';
            else
                selection = 'off';
            end
            
            % Todo: Bordertype should be a class property
            
            % Change highlight of table row background
            imageArgs = {'BorderType', 'bottom', 'Selection', selection};
            imagePathStr = obj.getTableRowBackground(imageArgs{:});
            hRow.HDivider.ImageSource = imagePathStr;
            
        end
        
        function pathStr = getTableRowBackground(obj, varargin)
        %getTableRowBorder Get path to image containing a table row border    
            
        
        % Todo: Implement with keywords for where border should be and for
        % background color
        %
        % Todo: Find a much smarter way to do this!
            
            imageName = strjoin( [{'TableBackground'}, varargin{:}], '_' );
            
            % If image already exists, return pathstr
            if isfield(obj.ImageGraphicPaths, imageName)
                pathStr = obj.ImageGraphicPaths.(imageName);
                return
            end
            
            % Else: Create and save a temporary image.
            h = obj.RowHeight + obj.RowSpacing;
            w = obj.TablePanelPosition(3);
            
            if any(strcmp(varargin(1:2:end), 'Selection'))
                matchedInd = find( strcmp(varargin(1:2:end), 'Selection') );
                matchedValue = varargin{matchedInd*2};
                switch matchedValue
                    case 'on'
                        bgColor = obj.RowSelectedBackgroundColor;
                    case 'off'
                        bgColor = obj.RowBackgroundColor;
                    otherwise
                        error('Invalid value for parameter name "Selection"')
                end
            else
                bgColor = obj.RowBackgroundColor;
            end
            
            % Create background image.
            colorData = ones(h,w,3) .* reshape(bgColor, 1, 1, 3);
            
            % Add border
            if  any(strcmp(varargin(1:2:end), 'BorderType'))
                matchedInd = find( strcmp(varargin(1:2:end), 'BorderType') );
                matchedValue = varargin{matchedInd*2};
                switch matchedValue
                    case 'left'
                        error('Bordertype is not implemented :(')
                    case 'right'
                        error('Bordertype is not implemented :(')
                    case 'bottom'
                        colorData(h, :, :) = repmat(obj.TableBorderColor, w, 1);
                    case 'top'
                        colorData(1, :, :) = repmat(obj.TableBorderColor, w, 1);
                    case 'all'
                        error('Bordertype is not implemented :(')
                    otherwise
                        error('Bordertype is not implemented :(')
                end
            end
            
            pathStr = [tempname, '.png'];
            imwrite(colorData, pathStr, 'png', 'Transparency', [1,1,1]);
            obj.ImageGraphicPaths.(imageName) = pathStr;
 
        end
        
        function deleteHeader(obj)
            delete(obj.ColumnHeaderBorder)
            
            for i = 1:numel(obj.ColumnHeaderLabels)
                delete(obj.ColumnHeaderLabels{i})
                if obj.ShowColumnHeaderHelp
                    delete(obj.ColumnLabelHelpButton{i})
                end
            end
                
            
        end

    end
    
    methods (Access = private, Hidden) % Internal updating
        
        function addTablePanelMargin(obj)
        %addTablePanelMargin Create image object which serves to give some 
        % space in the interior top part of a scrollable panel. 
        
            % Place empty image in top of table to add some space between
            % table and column header.
            obj.TableHeaderSpacer = uiimage(obj.TablePanel);
            obj.updateTablePanelMargin()
                    
        end

        function createTableRowBackgroundImages(obj)
            % Todo
        end
    
        function pathStr = getColumnHeaderRowBorder(obj)
        %getColumnHeaderRowBorder Get path to image containing a table row border    
        %
        % Same as getTableRowBorder, but this image is not so tall because
        % row spacing is not included
        
            % If image already exist return pathstr
            if isfield(obj.ImageGraphicPaths, 'ColumnHeaderRowBorder')
                pathStr = obj.ImageGraphicPaths.TableRowBorder;
                return
            end
            
            % Else: Create and save a temporary image.
            h = obj.RowHeight;
            w = obj.Position(3);

            colorData = ones(h,w,3);
            %alphaData = zeros(h,w,3);
            
            colorData(h, :, :) = repmat(obj.TableBorderColor, w, 1);
            
            pathStr = [tempname, '.png'];
            imwrite(colorData, pathStr, 'png', 'Transparency', [1,1,1]);
            obj.ImageGraphicPaths.TableRowBorder = pathStr;
 
        end
        
        function updateTablePanelMargin(obj)
        %updateTablePanelMargin Update position of image object that serves
        %to give some space in the interior top part of a scrollable panel.
            h = max(obj.RowLocations) + obj.RowHeight + 10;
            if isempty(h); h = 10; end
            obj.TableHeaderSpacer.Position = [1,h,0,10];
        end
    end
    
    methods 
        
        function addRow(obj, rowNumber, rowData)
        %addRow Add a row to the table.
            
            if nargin < 2
                addRow@applify.UiControlTable(obj)
            elseif nargin < 3
                addRow@applify.UiControlTable(obj, rowNumber)
            else
                addRow@applify.UiControlTable(obj, rowNumber, rowData)
            end
            
            obj.updateTablePanelMargin()
            
        end
        
        function removeRow(obj, rowNumber)
            
            removeRow@applify.UiControlTable(obj, rowNumber)
        
            obj.updateTablePanelMargin()

        end
    end
end