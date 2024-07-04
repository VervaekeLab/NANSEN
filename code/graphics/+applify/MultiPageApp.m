classdef MultiPageApp < uiw.abstract.AppWindow

    properties (Abstract, Constant, Access = protected)
        % Pages - Name of pages to display
        PageTitles (1,:) string
    end

    properties 
        ActivePageModule = []
    end

    properties (Access = protected)
        PageModules (1,1) dictionary
    end

    methods % Constructor

        function app = MultiPageApp(varargin)

            app.createLayout()
            app.createComponents()

            app.Figure.SizeChangedFcn = @(s, e) app.onFigureSizeChanged;
        end

    end

    methods (Abstract, Access = protected) % Creation
        module = createPageModule(app, hTabContainer)
    end

    methods (Access = protected) % Creation
       
        function createLayout(app)
            
            app.hLayout.MainPanel = uipanel('Parent', app.Figure, 'Tag', 'Main Panel');
            app.hLayout.MainPanel.BorderType = 'none';
            
            app.hLayout.TabGroup = uitabgroup(app.hLayout.MainPanel);
            app.hLayout.TabGroup.Units = 'normalized';
            %app.hLayout.TabGroup.Position = [0.025, 0.025, 0.95, 0.95];

            app.updateLayoutPositions()
        end

        function createTabPages(app)
            
            for i = 1:numel(app.PageTitles)
                
                pageTitle = app.PageTitles{i};
                
                hTab = uitab(app.hLayout.TabGroup);
                hTab.Title = pageTitle;

                %pageModule = app.createPageModule( hTab );
                %app.PageModules(pageTitle) = {pageModule};
            end
            
            % Add a callback function for when tab selection is changed
            app.hLayout.TabGroup.SelectionChangedFcn = @app.onTabChanged;
        end

        function initializeModules(app)
            
            for i = 1:numel(app.PageTitles)
                pageTitle = app.PageTitles{i};
                hTab = app.hLayout.TabGroup.Children(i);
                pageModule = app.createPageModule( hTab );
                app.PageModules(pageTitle) = {pageModule};
            end

            app.ActivePageModule = app.PageModules{ app.PageTitles(1) };
        end

        function createComponents(app)
            app.createTabPages()
        end


        % Subclass may override
        function updateLayoutPositions(app)
        
        
        end
    end

    methods (Access = protected) % Callbacks

        function onFigureSizeChanged(app)
            drawnow
            app.ActivePageModule.updateSize()
            drawnow
        end

        function onTabChanged(app, src, evt)
            
            pageTitle = evt.NewValue.Title;

            % % if ~isKey(app.PageModules, pageTitle)
            % %     thisTab = evt.NewValue;
            % %     pageModuleFcn = app.PageFactoryFcn( pageTitle );
            % %     pageModule = pageModuleFcn(thisTab, app);
            % %     app.PageModules( pageTitle ) = pageModule;
            % % end

            % Check if old page should be cleaned up
            currentPageModule = app.ActivePageModule;

            % Check if new page should be updated
            if isKey(app.PageModules, pageTitle)
                app.ActivePageModule = app.PageModules{ pageTitle };
                app.ActivePageModule.updateSize()
            else
                %evt.NewValue.Parent.SelectedTab = evt.OldValue;
                %Reset tab selected
                return
            end
            
            currentPageModule.deactivate()
            app.ActivePageModule.activate()
        end
    end
end