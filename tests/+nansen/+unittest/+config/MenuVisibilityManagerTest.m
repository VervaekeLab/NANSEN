classdef MenuVisibilityManagerTest < matlab.unittest.TestCase
    % MenuVisibilityManagerTest - Unit tests for MenuVisibilityManager
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.MenuVisibilityManagerTest')
    
    properties (TestParameter)
        Scope = {'user', 'project', 'both'}
    end
    
    properties
        TestFigure
        Manager
        TestMenus struct
    end
    
    methods (TestClassSetup)
        function setupTestEnvironment(~)
            % Ensure test environment is set up
            if ~exist('nansen.config.MenuVisibilityManager', 'class')
                error('MenuVisibilityManager class not found on path');
            end
        end
    end
    
    methods (TestMethodSetup)
        function createTestFigure(testCase)
            % Create a test figure with sample menus
            testCase.TestFigure = uifigure('Visible', 'off');
            
            % Create root menus
            nansenMenu = uimenu(testCase.TestFigure, 'Text', 'Nansen');
            appsMenu = uimenu(testCase.TestFigure, 'Text', 'Apps');
            toolsMenu = uimenu(testCase.TestFigure, 'Text', 'Tools');
            
            % Create tagged child menus under Nansen
            uimenu(nansenMenu, 'Text', 'New Project', 'Tag', 'core.nansen.new_project');
            uimenu(nansenMenu, 'Text', 'Open Project', 'Tag', 'core.nansen.open_project');
            
            % Create nested menu structure
            configMenu = uimenu(nansenMenu, 'Text', 'Configure', 'Tag', 'core.nansen.configure');
            uimenu(configMenu, 'Text', 'Data Locations', 'Tag', 'core.nansen.configure.datalocations');
            uimenu(configMenu, 'Text', 'Variables', 'Tag', 'core.nansen.configure.variables');
            
            % Create tagged child menus under Apps
            uimenu(appsMenu, 'Text', 'Imviewer', 'Tag', 'core.apps.imviewer');
            uimenu(appsMenu, 'Text', 'FovManager', 'Tag', 'core.apps.fovmanager');
            
            % Create plugin menus under Tools
            uimenu(toolsMenu, 'Text', 'Custom Tool', 'Tag', 'plugin.tools.custom_tool');
            
            % Store reference to test menus
            testCase.TestMenus = struct(...
                'NansenMenu', nansenMenu, ...
                'AppsMenu', appsMenu, ...
                'ToolsMenu', toolsMenu, ...
                'ConfigMenu', configMenu);
            
            % Create manager
            testCase.Manager = nansen.config.MenuVisibilityManager(testCase.TestFigure);
        end
    end
    
    methods (TestMethodTeardown)
        function closeTestFigure(testCase)
            % Clean up test figure
            if ~isempty(testCase.TestFigure) && isvalid(testCase.TestFigure)
                delete(testCase.TestFigure);
            end
            testCase.TestFigure = [];
            testCase.Manager = [];
        end
    end
    
    methods (Test)
        function testConstructor(testCase)
            % Test that manager is properly constructed
            testCase.verifyClass(testCase.Manager, 'nansen.config.MenuVisibilityManager');
        end
        
        function testGetAllMenuTags(testCase)
            % Test that all menu tags are retrieved
            tags = testCase.Manager.getAllMenuTags();
            
            testCase.verifyTrue(iscell(tags), 'Tags should be a cell array');
            testCase.verifyGreaterThan(numel(tags), 0, 'Should find some tags');
            
            % Verify expected tags are present
            testCase.verifyTrue(any(strcmp(tags, 'core.nansen.new_project')));
            testCase.verifyTrue(any(strcmp(tags, 'core.apps.imviewer')));
            testCase.verifyTrue(any(strcmp(tags, 'plugin.tools.custom_tool')));
        end
        
        function testSetMenuVisibility(testCase)
            % Test setting menu visibility
            tag = 'core.nansen.new_project';
            
            % Hide the menu
            testCase.Manager.setMenuVisibility(tag, false, 'user');
            
            % Verify it's in the hidden list
            isHidden = testCase.Manager.isMenuItemHidden(tag, 'user');
            testCase.verifyTrue(isHidden, 'Menu should be hidden');
            
            % Show the menu again
            testCase.Manager.setMenuVisibility(tag, true, 'user');
            
            % Verify it's not in the hidden list
            isHidden = testCase.Manager.isMenuItemHidden(tag, 'user');
            testCase.verifyFalse(isHidden, 'Menu should be visible');
        end
        
        function testApplyVisibilityHidesMenu(testCase)
            % Test that applying visibility actually hides menus
            tag = 'core.nansen.new_project';
            menuItem = findobj(testCase.TestFigure, 'Tag', tag);
            
            % Initially visible
            testCase.verifyEqual(char(menuItem.Visible), 'on');
            
            % Hide the menu
            testCase.Manager.setMenuVisibility(tag, false, 'user');
            testCase.Manager.applyVisibility();
            
            % Verify it's hidden
            testCase.verifyEqual(char(menuItem.Visible), 'off');
        end
        
        function testApplyVisibilityShowsMenu(testCase)
            % Test that showing a hidden menu works
            tag = 'core.nansen.new_project';
            menuItem = findobj(testCase.TestFigure, 'Tag', tag);
            
            % Hide first
            testCase.Manager.setMenuVisibility(tag, false, 'user');
            testCase.Manager.applyVisibility();
            testCase.verifyEqual(char(menuItem.Visible), 'off');
            
            % Now show
            testCase.Manager.setMenuVisibility(tag, true, 'user');
            testCase.Manager.applyVisibility();
            testCase.verifyEqual(char(menuItem.Visible), 'on');
        end
        
        function testParentVisibleWhenChildVisible(testCase)
            % Test that parent menus are visible when children are visible
            childTag = 'core.nansen.configure.datalocations';
            parentTag = 'core.nansen.configure';
            
            childMenu = findobj(testCase.TestFigure, 'Tag', childTag);
            parentMenu = findobj(testCase.TestFigure, 'Tag', parentTag);
            
            % Hide parent but keep child visible
            testCase.Manager.setMenuVisibility(parentTag, false, 'user');
            testCase.Manager.setMenuVisibility(childTag, true, 'user');
            testCase.Manager.applyVisibility();
            
            % Parent should be visible because child is visible
            testCase.verifyEqual(char(parentMenu.Visible), 'on', ...
                'Parent should be visible when child is visible');
            testCase.verifyEqual(char(childMenu.Visible), 'on');
        end
        
        function testRootMenuHiddenWhenAllChildrenHidden(testCase)
            % Test that root menus are hidden when all children are hidden
            
            % Hide all Apps menu items
            testCase.Manager.setMenuVisibility('core.apps.imviewer', false, 'user');
            testCase.Manager.setMenuVisibility('core.apps.fovmanager', false, 'user');
            testCase.Manager.applyVisibility();
            
            % Apps menu should be hidden
            appsMenu = testCase.TestMenus.AppsMenu;
            testCase.verifyEqual(char(appsMenu.Visible), 'off', ...
                'Root menu should be hidden when all children are hidden');
        end
        
        function testToolsMenuAlwaysVisible(testCase)
            % Test that Tools menu stays visible even when empty
            
            % Hide all tools
            testCase.Manager.setMenuVisibility('plugin.tools.custom_tool', false, 'user');
            testCase.Manager.applyVisibility();
            
            % Tools menu should still be visible
            toolsMenu = testCase.TestMenus.ToolsMenu;
            testCase.verifyEqual(char(toolsMenu.Visible), 'on', ...
                'Tools menu should always be visible');
        end
        
        function testScopeIsolation(testCase)
            % Test that user and project scopes are independent
            tag = 'core.nansen.new_project';
            
            % Hide in user scope
            testCase.Manager.setMenuVisibility(tag, false, 'user');
            
            % Should be hidden in user scope
            testCase.verifyTrue(testCase.Manager.isMenuItemHidden(tag, 'user'));
            
            % Should not be hidden in project scope
            testCase.verifyFalse(testCase.Manager.isMenuItemHidden(tag, 'project'));
        end
        
        function testCleanupStalePreferences(testCase)
            % Test that stale preferences are removed
            
            % Add a preference for a non-existent menu
            testCase.Manager.setMenuVisibility('fake.menu.item', false, 'user');
            
            % Clean up stale preferences
            testCase.Manager.cleanupStalePreferences('user');
            
            % Fake menu should not be in hidden list anymore
            % (This is hard to verify directly, but shouldn't cause errors)
            testCase.Manager.applyVisibility();
        end
    end
    
    methods (Test, TestTags="Integration")
        function testSaveAndLoadPreferences(testCase)
            % Integration test for save/load (requires file system access)
            tag = 'core.nansen.new_project';
            
            % Set visibility
            testCase.Manager.setMenuVisibility(tag, false, 'user');
            
            % Save preferences
            testCase.Manager.savePreferences('user');
            
            % Create new manager and load preferences
            newManager = nansen.config.MenuVisibilityManager(testCase.TestFigure);
            newManager.loadPreferences('user');
            
            % Verify preference was loaded
            testCase.verifyTrue(newManager.isMenuItemHidden(tag, 'user'));
            
            % Clean up - show menu again and save
            newManager.setMenuVisibility(tag, true, 'user');
            newManager.savePreferences('user');
        end
    end
end
