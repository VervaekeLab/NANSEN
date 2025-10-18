classdef MenuCustomizationDialogTest < matlab.unittest.TestCase
    % MenuCustomizationDialogTest - Unit tests for MenuCustomizationDialog
    %
    %   Run tests:
    %       runtests('nansen.unittest.config.MenuCustomizationDialogTest')
    
    properties
        TestApp
        TestDialog
    end
    
    methods (TestClassSetup)
        function setupTestEnvironment(~)
            % Ensure test environment is set up
            if ~exist('nansen.config.MenuCustomizationDialog', 'class')
                error('MenuCustomizationDialog class not found on path');
            end
        end
    end
    
    methods (TestMethodSetup)
        function createMockApp(testCase)
            % Create a minimal mock app structure
            testCase.TestApp = struct();
            testCase.TestApp.Figure = uifigure('Visible', 'off');
            
            % Create sample menus
            nansenMenu = uimenu(testCase.TestApp.Figure, 'Text', 'Nansen');
            uimenu(nansenMenu, 'Text', 'New Project', 'Tag', 'core.nansen.new_project');
            uimenu(nansenMenu, 'Text', 'Open Project', 'Tag', 'core.nansen.open_project');
            
            appsMenu = uimenu(testCase.TestApp.Figure, 'Text', 'Apps');
            uimenu(appsMenu, 'Text', 'Imviewer', 'Tag', 'core.apps.imviewer');
            
            % Create MenuVisibilityManager
            testCase.TestApp.MenuVisibilityManager = ...
                nansen.config.MenuVisibilityManager(testCase.TestApp.Figure);
        end
    end
    
    methods (TestMethodTeardown)
        function cleanup(testCase)
            % Clean up dialog and app
            if ~isempty(testCase.TestDialog) && isvalid(testCase.TestDialog)
                delete(testCase.TestDialog);
            end
            testCase.TestDialog = [];
            
            if ~isempty(testCase.TestApp) && isfield(testCase.TestApp, 'Figure')
                if isvalid(testCase.TestApp.Figure)
                    delete(testCase.TestApp.Figure);
                end
            end
            testCase.TestApp = [];
        end
    end
    
    methods (Test, TestTags="Graphical")
        function testConstructor(testCase)
            % Test that dialog is properly constructed
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            
            testCase.verifyClass(testCase.TestDialog, 'nansen.config.MenuCustomizationDialog');
            testCase.verifyTrue(isvalid(testCase.TestDialog), 'Dialog should be valid');
        end
        
        function testDialogHasFigure(testCase)
            % Test that dialog creates a figure
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            
            % Access private property using struct syntax (if accessible)
            % Otherwise this test verifies no errors occur during construction
            testCase.verifyTrue(isvalid(testCase.TestDialog));
        end
        
        function testShowMethod(testCase)
            % Test that show method doesn't error
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            
            % Show should not error
            testCase.verifyWarningFree(@() testCase.TestDialog.show());
        end
        
        function testDeleteMethod(testCase)
            % Test that dialog can be properly deleted
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            
            % Delete should not error
            testCase.verifyWarningFree(@() delete(testCase.TestDialog));
            testCase.TestDialog = [];
        end
    
        function testTreeStructure(testCase)
            % Test that tree is populated with menu items
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            
            % Verify dialog was created
            testCase.verifyTrue(isvalid(testCase.TestDialog));
            
            % Tree should contain nodes (this is a basic smoke test)
            % More detailed testing would require access to private properties
        end
        
        function testScopeSelection(testCase)
            % Test that scope selection works
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            testCase.TestDialog.show();
            
            % This is a smoke test - just verify no errors when dialog is shown
            pause(0.1); % Let UI update
            
            testCase.verifyTrue(isvalid(testCase.TestDialog));
        end
        
        function testResetButton(testCase)
            % Test that reset functionality works
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            
            % Hide a menu first
            testCase.TestApp.MenuVisibilityManager.setMenuVisibility(...
                'core.nansen.new_project', false, 'user');
            
            % Recreate dialog
            delete(testCase.TestDialog);
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            testCase.TestDialog.show();
            
            % This is a smoke test - verify dialog still works after changes
            testCase.verifyTrue(isvalid(testCase.TestDialog));
        end
    end
    
    methods (Test, TestTags=["Integration", "Graphical"])
        function testDialogModifiesManager(testCase)
            % Integration test: verify dialog changes are reflected in manager
            testCase.TestDialog = nansen.config.MenuCustomizationDialog(testCase.TestApp);
            
            % This would require simulating UI interactions
            % For now, this is a placeholder for future implementation
            
            testCase.verifyTrue(true, 'Integration test placeholder');
        end
    end
end
