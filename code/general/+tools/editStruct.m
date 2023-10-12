function [sOut, wasAborted] = editStruct(sIn, fieldNames, titleStr, varargin)
% editStruct opens a GUI for editing fields of a struct/object
    

    % Determine which fieldnames to include for editing...
    if nargin < 2 || isempty(fieldNames) || isequal(fieldNames, 'all') 
        if isa(sIn, 'struct')
            fieldNames = fields(sIn);
            
        elseif isobject(sIn) && isa(sIn, 'handle')
            fieldNames = properties(sIn);
%             dependentProperties = findAttrValue(sIn, 'Dependent');
%             fieldNames = setdiff(fieldNames, dependentProperties, 'stable');
            warning('Cancel functionality of handle objects not implemented')
        
        elseif isobject(sIn) && ~isa(sIn, 'handle')
           %TODO get properties of a class
           	warning('Non-handle class object not implemented')

        else
            error('Input must be a struct or an object')
        end 
    end
    
    if nargin >= 3 && ~isempty(titleStr) % Preserve backwards compatibility.
        varargin = [varargin, {'Title', titleStr}];
    end
    
    wasAborted = false;
    
    % Check if this is a struct of structs. 
    % In that case, make a tab/page for each of them.
    convertOutputToStruct = false;
    if isstruct(sIn)
        subfields = fieldnames(sIn);
        isSubstruct = cellfun(@(name) isstruct(sIn.(name)), subfields);
        
        if all(isSubstruct)
            convertOutputToStruct = true;
            names = fieldnames(sIn);
            sIn = struct2cell(sIn);
            varargin = [varargin, {'Name', names}];
        end
    end
    
    try

        sEditor = structeditor(sIn, varargin{:});
        sEditor.IsModal = true;
        sEditor.waitfor()

        if sEditor.wasCanceled
            sOut = sEditor.dataOrig;
            wasAborted = true;
        else
            sOut = sEditor.dataEdit;
        end
        
        if convertOutputToStruct % See above conversion...
            sOut = cell2struct(sOut, names);
        end
        
        delete(sEditor)
        
        if nargout == 1
            clear wasAborted
        end
    
    catch ME
        
        switch ME.identifier
            case 'MATLAB:class:InvalidSuperClass'
                
                if contains(ME.message, 'uiw.mixin.AssignPVPairs')
                    msg = 'Settings window requires the Widgets Toolbox to be installed';
                    errordlg(msg)
                    error(msg)
                end
                
            otherwise
                rethrow(ME)
        end
        
        
        
        % Create the figure
        guiFig = createFigure(titleStr);
        guiFig.UserData.sBak = sIn;   
        guiFig.UserData.sTmp = sIn;

        try

            % Add all components
            createComponents(guiFig, sIn, fieldNames)

            % Create a scrollbar if all components does not fit
            createScrollBar(guiFig)

            uiwait(guiFig)
            sOut = guiFig.UserData.sOut;
            delete(guiFig)
            
            if nargout == 1
                clear wasAborted
            end
            
        catch 
            errordlg('Something went wrong')
            delete(guiFig)
        end

    end
            
end


%TODO implement scroller
function guiFig = createFigure(titleStr)
% Creates figure window for editing struct

    screenSize = get(0, 'ScreenSize');
    screenMarginY = 100; % pixels
    height = screenSize(4) - 2*screenMarginY;
    width = screenSize(4) * 0.6;
    screenMarginX = screenSize(3)*0.33 - width/2;

    guiFig = figure();
    guiFig.MenuBar = 'none';
    guiFig.Position = [screenMarginX, screenMarginY, width, height];
    guiFig.Resize = 'off';
    guiFig.Name = titleStr;
    guiFig.NumberTitle = 'off';
%     guiFig.WindowScrollWheelFcn = @mouseScrollCallback;
    guiFig.WindowKeyPressFcn = @keyboardShortcuts;
    guiFig.CloseRequestFcn = {@quit, 'Cancel'};

end


function keyboardShortcuts(src, event)

    currentObject = gco;

    if isa(currentObject, 'matlab.ui.control.UIControl')
        if isequal(currentObject.Style, 'edit')
            return
        end
    end

    switch event.Key
        case 'x'
            quit(src, [], 'Cancel')
        case 's'
            quit(src, [], 'Save')
    end
end

% Needed for scroller:
% %     guiPanel.Units = 'pixel';
% %     panelPosition = get(guiPanel, 'Position');
function createComponents(guiFig, S, fieldNames)
% Create components in figure for editing properties

    guiPanel = uipanel(guiFig);
    guiPanel.Position = [0.05, 0.07, 0.9, 0.9];
    guiPanel.Units = 'pixel';

    rowHeight = 30;
    rowSep = 10;
    totHeight = guiPanel.Position(4);
%     guiPanel.Units = 'normalized';

    
    y = rowSep;

    % Go through each property and make an inputfield for it. Each
    % editfield has a Tag which is the same as the propertyname. 
    % This is how to refer to them in other functions of the gui.
    for p = numel(fieldNames):-1:1

        currentProperty = fieldNames{p};
        propertyClass = class(S.(currentProperty));
        
        if strcmp(currentProperty, 'sessionID')
            continue
        elseif ~contains(propertyClass, {'logical', 'cell', 'double', 'char', 'struct', 'uint16', 'single', 'uint8'})
            continue
        end

        propertyClass = class(S.(currentProperty));

        switch propertyClass
            case 'struct'   % Make input for each field of struct property
                propertyFields = fields(S.(currentProperty));
                
                % Make a dropdown selection
                if contains('Selection', propertyFields)
                    val = S.(currentProperty);
                    addInputField(guiPanel, y, currentProperty, val)
                    y = y + rowHeight + rowSep;
                else
                    for i = 1:numel(propertyFields)
                        currentField = propertyFields{i};
                        name = strcat(currentProperty, '.', currentField);
                        val = eval(strcat('S', '.', name));
                        addInputField(guiPanel, y, name, val)
                        y = y + rowHeight + rowSep;
                    end
                end

            otherwise
                val = eval(strcat('S', '.', currentProperty));
                addInputField(guiPanel, y, currentProperty, val)
                y = y + rowHeight + rowSep;
        end
        
    end
    
    if y < totHeight
        difference = totHeight - y;
        guiPanel.Position(4) = guiPanel.Position(4) - difference;
        guiFig.Position(4) = guiFig.Position(4) - difference;
        screenSize = get(0, 'ScreenSize');
        guiFig.Position(1:2) = screenSize(3:4)/2 - guiFig.Position(3:4)/2;
    end
    
    % Add save and cancel buttons
    
    saveButton = uicontrol(guiFig, 'style', 'pushbutton');
%     saveButton.Units = 'normalized';
    saveButton.Position = [guiFig.Position(3)/4-75, 15, 150, 20];
    saveButton.String = 'Save and Close';  
    saveButton.FontUnits = 'normalized';
    saveButton.FontSize = 0.7;
    saveButton.Callback = {@quit, 'Save'};

    cancelButton = uicontrol(guiFig, 'style', 'pushbutton');
%     cancelButton.Units = 'normalized';
    cancelButton.Position = [guiFig.Position(3)/4*3-50, 15, 100, 20];
    cancelButton.String = 'Cancel';
    cancelButton.FontUnits = 'normalized';
    cancelButton.FontSize = 0.7;
    cancelButton.Callback = {@quit, 'Cancel'};
    
end


% Note inputbox belongs to guiPanel
function addInputField(guiPanel, y, name, val)
% Add input field for editing of property value
%       y       : y position in panel
%       name    : name of property. Used for text field and Tag
%       val     : value f property. Assigned to input field.

    
    % Create a textbox with the property name
    textbox = uicontrol(guiPanel, 'style', 'text');
    textbox.String = varname2label(name);
    textbox.Units = 'pixel';
    textbox.Position = [20, y-5, 150, 30];
    textbox.HorizontalAlignment = 'right';
    textbox.Tag = name;

    % Create an input field for editing of propertyvalues
    switch class(val)
        case 'logical'
            inputbox = uicontrol(guiPanel, 'style', 'checkbox');
            inputbox.Value = val;
        case 'cell'
            if all(ischar([ val{:} ]))
                inputbox = uicontrol(guiPanel, 'style', 'edit');
                inputbox.String = strjoin(val, ', ');
            end
        case 'char'
            inputbox = uicontrol(guiPanel, 'style', 'edit');
            inputbox.String = val;
            
        case 'struct'
            fields = fieldnames(val);
            % Create a dropdown selection
            if contains('Selection', fields)
                inputbox = uicontrol(guiPanel, 'style', 'popupmenu');
                inputbox.String = val.Alternatives;
                inputbox.Value = find(contains(val.Alternatives, val.Selection));
            else
                % Not implemented
            end
            
            % skip for now
            
        case {'double', 'single', 'uint16', 'uint8'}
            inputbox = uicontrol(guiPanel, 'style', 'edit');
            inputbox.String = num2str(val);
            
        otherwise
            % skip for now
    end

%     inputbox.Units = 'normalized';
    inputbox.Position = [200, y, 200, 30];
    inputbox.HorizontalAlignment = 'left';
    inputbox.Tag = name;
    inputbox.Callback = @editCallback_propertyValueChange;

    % Create a browsebutton if property is a path.
    if contains(lower(name), {'path', 'drive'}) && isa(val, 'char')
        browseButton = uicontrol(guiPanel, 'style', 'pushbutton');
        browseButton.String = '...';
        browseButton.Units = 'pixel';
        browseButton.Position = [420, y+2, 25, 25];
        browseButton.Tag = name;
        browseButton.Callback = @buttonCallback_openBrowser;
    end

end


function editCallback_propertyValueChange(src, ~)
% Callback for value change in inputfields. Update session property
%
%   Updates the value of the property corresponding to inputfield.

    guiPanel = src.Parent;
    guiFig = guiPanel.Parent;
    
    name = src.Tag;

    switch src.Style
        case 'edit'
            val = src.String;
        case 'checkbox'
            val = src.Value;
        case 'popupmenu'
            val = src.String{src.Value};
    end

    % Convert value to a string for the eval function later.
    switch class(eval(['guiFig.UserData.sTmp.', name]))
        case {'double', 'single', 'uint16', 'uint8'}
            if isempty(val)
                val = '[]';
            else
                val = strcat('[', num2str(val), ']');
            end

        case 'logical'
            if val
                val = 'true';
            else
                val = 'false';
            end

        case 'cell'
            val = strcat('{', '''', val, '''', '}');

        case 'char'
            val = ['''' val ''''];
            
        case 'struct'
            fields = fieldnames(guiFig.UserData.sTmp.(name));
            if contains('Selection', fields)
                val = ['''' val ''''];
                name = sprintf('(''%s'').Selection', name);
            else
                %Not implemented
            end

    end

    % Check if new value is different than old, and update if so
    newVal = eval(val);
    oldVal = eval(['guiFig.UserData.sTmp.', name]);

    if isequal(newVal, oldVal)
        return
    else
        % Need eval function to assign fields in properties that are
        % structs.
        eval(['guiFig.UserData.sTmp.', name, ' = ', val , ';'])
    end

end


function createScrollBar(guiFig)     
% Creates a scrollbar on a panel if all the fields does not fit on the panel

    guiPanel = findobj(guiFig, 'Type', 'uipanel');

    % Determine position of bottom most field
    fields = findobj(guiPanel, 'Style', 'text');
    fieldPos1 = get(fields(1), 'Position'); % Last field added is the first field in the list

    if fieldPos1(2) < 0
        % Calculate range and y-positions of scrollbar
        fieldPos2 = get(fields(2), 'Position');
        yPad = fieldPos2(2) - fieldPos1(4) - fieldPos1(2);
        panelHeight = 1 + yPad + abs(fieldPos1(2));
        fieldPosTop = get(fields(end), 'Position');
        topMargin = 1 - fieldPosTop(2) - fieldPosTop(4);

        % Add a java scrollbar
        jScrollbar = javaObjectEDT('javax.swing.JScrollBar');
        jScrollbar.setOrientation(jScrollbar.VERTICAL);                          
        [jScroller, jScrollContainer] = javacomponent(jScrollbar);

        % Add a callback for value changes
        jScroller = handle(jScroller, 'CallbackProperties');
        set(jScroller, 'AdjustmentValueChangedCallback', {@scrollValueChange, guiPanel});

        % Set scrollbar range and positions
        set(jScroller, 'maximum',  panelHeight * 100, 'VisibleAmount', 100);
        scrollPos = [0.95, yPad, 0.05, 1-topMargin-yPad]; %% need y coordinates...
        set(jScrollContainer, 'Parent', guiPanel, 'units', 'normalized', 'Position', scrollPos)
        
        guiPanel.UserData.scrollBar = jScroller;
        guiPanel.UserData.lastScrollValue = get(jScroller, 'value');
    end

end 


function scrollValueChange(scroller, ~, guiPanel)        
% Callback for value change on scroller belonging to panel. Scrolls up or down.

    delta = scroller.value - guiPanel.UserData.lastScrollValue;
    guiPanel.UserData.lastScrollValue = scroller.value;

    % Get editboxes and texts of panel
    %editfields = findobj(obj.guiPanel, 'Style', 'edit');
    textfields = findobj(guiPanel, 'Style', 'text');

    % Move fields in panel.
    for i = 1:length(textfields)
        fieldPos = get(textfields(i), 'Position');
        fieldPos(2) = fieldPos(2) + (delta)/100;
        set(textfields(i), 'Position', fieldPos)

        currentTag = get(textfields(i), 'Tag');

        inputfields = findobj(guiPanel, 'Tag', currentTag, '-not', 'Style', 'text');

        for j = 1:numel(inputfields)
            fieldPos = get(inputfields(j), 'Position');
            fieldPos(2) = fieldPos(2) + (delta)/100;
            set(inputfields(j), 'Position', fieldPos)
        end

    end

end


function mouseScrollCallback(src, event)
% Callback for mousescroll. Controls scrollslider in panel.

    i = event.VerticalScrollCount;
    mousePoint = get(src, 'CurrentPoint');
    x = mousePoint(1); y = mousePoint(2);

    guiPanel = findobj(src, 'Type', 'uipanel');

    set(guiPanel, 'Units', 'pixel')
    panelPos = get(guiPanel, 'Position');
    set(guiPanel, 'Units', 'normalized')

    panelLim = [panelPos(1:2), panelPos(1:2) + panelPos(3:4)];

    if x > panelLim(1) &&  x < panelLim(3) && y > panelLim(2) &&  y < panelLim(4)
            scrollvalue = get(guiPanel.UserData.scrollBar, 'value');
            set(guiPanel.UserData.scrollBar, 'value', scrollvalue + i)
    end

end


function buttonCallback_openBrowser(src, ~)
% Button callback for browse button. Used to change path
    
    guiPanel = src.Parent;
    guiFig = guiPanel.Parent;

    propertyName = src.Tag;
    oldPathString = guiFig.UserData.sTmp.(propertyName);

    if isempty(oldPathString)
        initPath = '/';
    else
        [initPath, ~, ~] = fileparts(oldPathString);
    end


    if contains(lower(src.Tag), {'file'})
        [fileName, folderPath, ~] = uigetfile({'*', 'All Files (*.*)'}, '', initPath);
        pathString = fullfile(folderPath, fileName);
    elseif contains(lower(src.Tag), {'path', 'drive'})
        pathString = uigetdir(initPath);
    end

    if ~pathString
        return
    else
        if isequal(oldPathString, pathString)
            return
        else
            guiFig.UserData.sTmp.(propertyName) = pathString;
            inputfield = findobj(guiPanel, 'Tag', propertyName, 'Style', 'edit');
            inputfield.String = pathString;
        end
    end

end


% Is src always guiFig? What are userdata fieldnames?
function quit(src, ~, action)
    
    if isa(src, 'matlab.ui.control.UIControl')
        guiFig = src.Parent;
    else
        guiFig = src;
    end

    switch action
        
        case 'Cancel'
            guiFig.UserData.sOut = guiFig.UserData.sBak;
            guiFig.UserData.sOut.Canceled = true;
        case 'Save'
            guiFig.UserData.sOut = guiFig.UserData.sTmp;
            guiFig.UserData.sOut.Canceled = false;
    end
    
    uiresume(guiFig)
    
end


function label = varname2label(varname)
% Convert a camelcase variable name to a label where each word starts with
% capital letter and is separated by a space.
%
%   label = varname2label(varname) insert space before capital letters and
%   make first letter capital
%
%   Example:
%   label = varname2label('helloWorld')
%   
%   label = 
%       'Hello World'

if ~ischar(varname); varname = inputname(1); end

capLetterPos = regexp(varname, '[A-Z, 1-9]');

for i = fliplr(capLetterPos)
    if i ~= 1
        varname = insertBefore(varname, i , ' ');
    end
end

varname(1) = upper(varname(1));
label = varname;

end


