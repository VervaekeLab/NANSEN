# Nansen Side Menu

A side panel with quick action buttons for the Nansen application.

## Overview

The `SideMenu` class provides a convenient right-side panel containing buttons for frequently used actions in the Nansen application. This improves workflow efficiency by providing quick access to common tasks without navigating through menus.

## Features

- **Quick Action Buttons**: Access common actions with a single click
- **Theme Integration**: Automatically matches the Nansen application theme
- **Keyboard Shortcut**: Toggle visibility with the `s` key
- **Menu Integration**: Also accessible via the Nansen menu

## Available Actions

The side menu currently includes the following action buttons:

1. **Refresh Table** - Refresh the current metatable view
2. **Refresh Data** - Refresh data location information
3. **Preferences** - Open application preferences
4. **Save Table** - Save the current metatable
5. **Clear Cache** - Clear the SessionObject cache
6. **Project Folder** - Open the current project folder

## Usage

### Toggling the Side Menu

There are three ways to show/hide the side menu:

1. **Keyboard Shortcut**: Press the `s` key
2. **Menu**: Navigate to `Nansen > Toggle Side Menu`
3. **Programmatically**: Use the app reference:
   ```matlab
   app.SideMenu.toggle()  % Toggle visibility
   app.SideMenu.show()    % Show
   app.SideMenu.hide()    % Hide
   ```

### Customizing Buttons

To add or modify buttons, edit the `ButtonConfigs` property in the `SideMenu` class:

```matlab
ButtonConfigs = struct(...
    'YourButtonName', struct(...
        'Label', 'Button Text', ...
        'Icon', '', ...  % Optional icon path
        'Callback', @(app, ~, ~) app.yourMethod(), ...
        'Tooltip', 'Helpful description') ...
)
```

## Implementation Details

### Class Location
- File: `/code/apps/+nansen/SideMenu.m`
- Namespace: `nansen.SideMenu`

### Integration Points

The side menu is integrated into the Nansen App in the following ways:

1. **Property Declaration**: Added as a property in `nansen.App`
2. **Initialization**: Created in `createSideMenu()` method during app startup
3. **Layout Updates**: Position updated in `updateLayoutPositions()`
4. **Theme Support**: Theme applied in `onThemeChanged()`
5. **Keyboard Support**: Toggle shortcut in `onKeyPressed()`

### Parent Container

The side menu uses the existing `app.hLayout.SidePanel` which was previously inactive.

## Extending the Side Menu

To add new functionality:

1. Add a new button configuration to the `ButtonConfigs` property
2. Implement the corresponding callback method in the `nansen.App` class
3. The button will automatically appear in the side menu

## Technical Details

- **Superclass**: `handle` and `applify.HasTheme`
- **Theme Support**: Inherits theme colors from parent app
- **Width**: Default 200 pixels (configurable via `Width` property)
- **Visibility**: Managed via `IsVisible` boolean property
