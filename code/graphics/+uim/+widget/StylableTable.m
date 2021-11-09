classdef StylableTable < uiw.widget.Table
%StylableTable Extends uiw.widget.Table with methods for increased
%flexibility in customizing the table appearance and layout.


    %Todo
    % [ ] Add property for horizontal and vertical scrollbar valuechanged 
    %     callbacks.
    % [ ] Todo: Add methods for plotting custom scrollbars.
    % [ ] Add methods for changing column properties (names, maybe editable
    %     and format) without invoking onStyleChangedMethod from
    %     uiw.widget.Table
    % [ ] How can I remove column header

    
    properties
        Theme uim.style.tableTheme = uim.style.tableLight
        ShowHorizontalLines = true
        ShowVerticalLines = false
        ShowColumnHeader = true
        
        UseDefaultHeader = true
        
        HeaderPressedCallback = []
    end
    
    properties %(Access = protected, Dependent)
        JTable
    end
    
    properties (Dependent)    
        KeyPressCallback
    end
    
    properties (Access = protected)
        JVScroller
        JHScroller
        JTableHeader
        JRandomContainer % table is inside this container, with 1 pixel margins so this appears as a border....wtf....
    
        % Following properties are used to detect if column header is
        % changed via the user interface by mouse drag actions.
        WasMouseDraggedInHeader = false;
        OldColumnWidth = []
    end
    
    events
        ColumnWidthChanged % Event listener for if column width changes (if user drags column headers to resize)
    end
    
    
    methods
        function obj = StylableTable(varargin)
            
            warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')
            
            obj@uiw.widget.Table(varargin{:})
            obj.retrieveJavaHandles()
            
            obj.updateGridLines()
            
            %obj.changeCheckboxRenderer()
            
            % Redraw (these methods are part of the superclass constructor,
            % but they are not run if the class is a subclass instance, so
            % they need to be invoked explicitly here.
            obj.onResized();
            obj.onEnableChanged();
            obj.redraw();
            obj.onStyleChanged();
            
            drawnow
            %obj.IsConstructed = true;
            obj.updateTheme()
            obj.updateColumnHeaderVisibility()
            
            warning('on', 'MATLAB:ui:javacomponent:FunctionToBeRemoved')

        end
        
        function delete(obj)
            
            % Explicitly delete handles to Java objects?
            
        end % destructor
        
    end
    
    methods (Access = protected) % Internal creation
        
        function retrieveJavaHandles(obj)
        %retrieveJavaHandles Retrieve java handles that will be modified
            obj.JVScroller = obj.JScrollPane.getComponent(1);
            obj.JHScroller = obj.JScrollPane.getComponent(2);
            obj.JTableHeader = obj.JTable.TableHeader; %??
            
            jTH = handle(obj.JTableHeader, 'CallbackProperties');
            set(jTH, 'MousePressedCallback', obj.HeaderPressedCallback)
            
            % Add following callbacks to trigger a column header resize if
            % mouse was dragged in header (Might have been user resizing
            % the column width of a column, and it seems like there is a
            % bug in the table widget when this happens, i.e the table
            % header size does not match the table size.
            set(jTH, 'MouseDraggedCallback', @obj.onMouseDraggedInHeader )
            set(jTH, 'MouseReleasedCallback', @obj.onMouseReleasedFromHeader)
            

            obj.JScrollPane.AncestorAddedCallback = @(s,e) obj.retrieveAncestorContainer();
        end
        
        function retrieveAncestorContainer(obj)
            obj.JRandomContainer = obj.JScrollPane.getParent.getParent.getParent.getParent;
            obj.updateTheme()
        end
        
        function createColumnHeaderDragListener(obj)
            % not used but ill keep it for now. Interestingly, if the
            % handle for the table header is retrieved here, there is no
            % available callback properties, but as far as I know, it is
            % the same handle which is retrieved in retrieveJavaHandles.
            jTH = handle(obj.JTableHeader, 'CallbackProperties');

            jHeader = handle( obj.JControl.getTableHeader(), 'CallbackProperties' );
            set(jHeader, 'MouseDraggedCallback', @(s,e, str) disp('bb'))
            
        end
    end
    
    
    methods
        
        function xOffset = getHorizontalScrollOffset(obj)
            xOffset = get(obj.JHScroller, 'Value');
        end
        
        function showHorizontalScroller(obj)
            set(obj.JHScroller, 'PreferredSize', java.awt.Dimension(100, 15) );
            obj.JScrollPane.updateUI()
        end
        
        function showVerticalScroller(obj)
            set(obj.JVScroller, 'PreferredSize', java.awt.Dimension(15, 100) );
            obj.JVScroller.updateUI()
        end
        
        function hideHorizontalScroller(obj)
            % Set preferred size of scroller to 0 to hide it
            set(obj.JHScroller, 'PreferredSize', java.awt.Dimension(100, 0) );
            obj.JScrollPane.updateUI()
        end
        
        function hideVerticalScroller(obj)
            % Set preferred size of scroller to 0 to hide it
            set(obj.JVScroller, 'PreferredSize', java.awt.Dimension(0, 100) );
            obj.JVScroller.updateUI()
        end
        
    end
    
    
    methods
        function set.Theme(obj, newTheme)
            obj.Theme = newTheme;
            obj.updateTheme()
        end
        
        function changeColumnWidths(obj, newWidths)
        %changeColumnWidths Method for updating column widths
        %
        %   I experienced that ColumnPreferredWidth need to be updated in
        %   order for columnwidths to actually change. In addition, I turn
        %   the flag for IsConstructed off during update to prevent the 
        %   onStyldeChanged method of the superclass being invoked. This
        %   causes some ugly flickers because some colors are changed back
        %   to defaults.
            
            obj.IsConstructed = false;
            obj.ColumnPreferredWidth = newWidths;
            obj.ColumnWidth = newWidths;
            obj.IsConstructed = true;

            obj.updateColumnHeaderWidth()
        end
        
        function set.ShowHorizontalLines(obj, newValue)
            assert(islogical(newValue), 'Value must be logical')
            obj.ShowHorizontalLines = newValue;
            obj.updateGridLines()
        end
        
        function set.ShowVerticalLines(obj, newValue)
            assert(islogical(newValue), 'Value must be logical')
            obj.ShowVerticalLines = newValue;
            obj.updateGridLines()
        end
        
        function set.ShowColumnHeader(obj, newValue)
            assert(islogical(newValue), 'Value must be logical')
            obj.ShowColumnHeader = newValue;
            obj.updateColumnHeaderVisibility()
        end
        
        function set.KeyPressCallback(obj, newValue)
            
        end
        
        function jTable = get.JTable(obj)
            jTable = obj.JControl;
        end
    end
    
    
    methods (Access = protected) % Internal updating
        
        function updateTheme(obj)
            if ~obj.IsConstructed; return; end
            
            % Function handle for converting rgb vector to java color
            jRGB = @(rgb) java.awt.Color(rgb(1), rgb(2), rgb(3));
            
            
            % Do stuff here!
            
%             % Convert to javacolors.
%             bgColor2 = obj.rgb2jrgb( S.tableBackgroundColor );
%             fgColor = obj.rgb2jrgb( S.tableForegroundColor );
%             
%             jViewPort = getappdata(obj.hTableView, 'JViewPort');
%             jScrollPane = getappdata(obj.hTableView, 'jScrollPane');
% 
%             % Set background color of table viewport (area available for table)
%             set(jViewPort, 'background', S.bgColor);
            
            obj.BackgroundColor = obj.Theme.CellColorUnmodified;
            obj.JTable.GridColor = jRGB( obj.Theme.GridColor );

            if ~obj.UseDefaultHeader
                % This creates ugly borders around the column header cells...
                obj.JTableHeader.setForeground( jRGB(obj.Theme.HeaderForegroundColor) );
                obj.JTableHeader.setBackground( jRGB(obj.Theme.HeaderBackgroundColor) );
                obj.JScrollPane.Background = jRGB(obj.Theme.HeaderBackgroundColor);
            end
            
            obj.JTable.Foreground = jRGB(obj.Theme.TableForegroundColor);
            obj.JTable.Background = jRGB(obj.Theme.CellColorModified);
            
            obj.JTable.selectionForeground = jRGB(obj.Theme.TableForegroundColorSelected);
            obj.JTable.selectionBackground = jRGB(obj.Theme.TableBackgroundColorSelected);
            
            obj.JTable.ModifiedCellColor = jRGB(obj.Theme.CellColorModified);
            obj.JTable.UnmodifiedCellColor = jRGB(obj.Theme.CellColorUnmodified);
            
            obj.JTable.sortArrowForeground = jRGB(obj.Theme.SortArrowForeground);
            obj.JTable.sortOrderForeground = jRGB(obj.Theme.SortOrderForeground);
            %obj.JTable.MarginBackground = S.bgColor;
            
            
            %borderColor = java.awt.Color(0.4,0.4,0.4);
            
            % Set table border.
            borderColor = jRGB(obj.Theme.BorderColor);
            w = obj.Theme.BorderWidth;
            tableBorder = javax.swing.border.LineBorder(borderColor, w, 0);
            obj.JScrollPane.setBorder(tableBorder)
            
            
% %             hCellRenderer = obj.JControl.getCellRenderer(0,0);
% %             hCellRenderer.setForeground(jRGB(obj.Theme.TableForegroundColor))

            
            % Set background of container that is slightly bigger than
            % table and therefor appear as a border.
            if ~isempty(obj.JRandomContainer)
                obj.JRandomContainer.setBackground( jRGB(obj.Theme.CellColorUnmodified) )
            end
        end
        
        function updateGridLines(obj)
        %updateGridLines Update appearance of gridlines between cells
            
            hSpacing = double(obj.ShowVerticalLines)*0;
            vSpacing = double(obj.ShowHorizontalLines)*1;
            obj.JTable.IntercellSpacing = java.awt.Dimension(hSpacing, vSpacing);

            obj.JTable.ShowVerticalLines = obj.ShowVerticalLines;
            obj.JTable.ShowHorizontalLines = obj.ShowHorizontalLines;
        end
        
        function updateColumnHeaderVisibility(obj)
            if ~obj.IsConstructed; return; end
            
            if obj.ShowColumnHeader
                tableHeader = obj.JTable.getTableHeader();
                set(obj.JTableHeader, 'PreferredSize', java.awt.Dimension(100,obj.RowHeight))
                set(tableHeader, 'PreferredSize', java.awt.Dimension(100, obj.RowHeight))
            else
                set(obj.JTableHeader, 'PreferredSize', java.awt.Dimension(100,0))
                tableHeader = obj.JTable.getTableHeader();
                set(tableHeader, 'PreferredSize', java.awt.Dimension(100, 0))
                set(tableHeader, 'MaximumSize', java.awt.Dimension(100, 0))
            end
            
        end
        
        function changeCheckboxRenderer(obj)
        %changeCheckboxRenderer Test, does any of this change things...?    
            h = obj.JTable.getCellRenderer(1,2);
            %set(h, 'BorderPainted', false);
            
            jRGB = @(rgb) java.awt.Color(rgb(1), rgb(2), rgb(3));

            set(h, 'Background', jRGB([1,0,1]));
            set(h, 'Foreground', jRGB([0,1,0]));

            set(h, 'Opaque', 0)
            %set(h, 'ContentAreaFilled', 0)
            %set(h, 'FocusPainted', 0)
            
            
        end
        
        function updateColumnHeaderWidth(obj)
        %updateColumnHeaderWidth
        %
        % Dont know why, but this needs to be done sometimes if the total
        % width of the column header is changed, either by adding or
        % removing columns, or if individual column widths are changed.
        % In some cases, the table and the tabler header are decoupled on
        % horizontal scrolling if this is not done...
        
        % Todo: Remove all commented stuff
        
            % Adjust font of headers too
            jHeader = obj.JControl.getTableHeader();
%             jHeader.setFont(obj.getJFont());
%             headerMinSize = jHeader.getMinimumSize();
%             headerMinSize.height = headerHeight;
%             jHeader.setMinimumSize(headerMinSize)
%             headerMaxSize = jHeader.getMaximumSize();
%             headerMaxSize.height = headerHeight;
%             jHeader.setMaximumSize(headerMaxSize)
            headerSize = jHeader.getPreferredSize();
%             headerSize.height = headerHeight;
            headerSize.width = sum(obj.ColumnWidth);
            jHeader.setPreferredSize(headerSize)
        end
        
        function onMouseDraggedInHeader(obj, src, evt)
        %onMouseDraggedInHeader Used to test if column widths are changed
            if ~obj.WasMouseDraggedInHeader
                obj.WasMouseDraggedInHeader = true;
                obj.OldColumnWidth = obj.ColumnWidth;
            end
        end
        
        function onMouseReleasedFromHeader(obj, src, evt)
        %onMouseReleasedFromHeader Used to test if column widths are changed
            if obj.WasMouseDraggedInHeader
                if any(obj.ColumnWidth ~= obj.OldColumnWidth)
                    obj.updateColumnHeaderWidth()
                    obj.notify('ColumnWidthChanged', event.EventData)
                end
                obj.WasMouseDraggedInHeader = false;
            end
        end
        
    end
    
end