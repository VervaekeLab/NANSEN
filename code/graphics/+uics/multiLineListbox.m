function listOut = multiLineListbox(listIn, varargin)

    params = struct();
    params.Title = '';
    params.Theme = nansen.theme.getThemeColors('dark-purple');
    params.ReferencePosition = [];
    
    params = utility.parsenvpairs(params, 1, varargin{:});


    if nargin < 1
        listIn = {};
    end
    
    originalList = listIn;

    MARGINS = [20, 70, 20, 20];
    SPACING = [20, 20];
    
    bgColor = params.Theme.FigureBgColor;

    f = figure('MenuBar', 'none', 'Resize', 'off');
    f.NumberTitle = 'off';
    if isempty(params.Title)
        f.Name = 'Edit List';
    else
        f.Name = params.Title;
    end
    
    hPanel = uipanel(f);
    hPanel.BorderType = 'none';
    hPanel.BackgroundColor = bgColor;
    
    tmpPanel = uipanel(f);
    tmpPanel.BorderType = 'none';
    tmpPanel.BackgroundColor = bgColor;
    %tmpPanel.Visible = 'off'; % Debug...
    
    %uicc = uim.UIComponentCanvas(hPanel);
    
    buttonNames = {'Add', 'Edit', 'Remove', 'Move Up', 'Move Down'};
    numButtons = numel(buttonNames);
    
  % % Configure layout of components
    buttonSize = [80, 18];
    
    editSize = [150, 20];
   
    componentWidth = editSize(1) + SPACING(1) + buttonSize(1);
    componentHeight = buttonSize(2) .* numButtons + (numButtons-1) * SPACING(2);
    
    f.Position(3:4) = [componentWidth, componentHeight] + sum(MARGINS([1,2;3,4]));
    H = f.Position(4); % Figure Height
    
    if ~isempty(params.ReferencePosition)
        uim.utility.layout.centerObjectInRectangle(f, params.ReferencePosition)
    end
     
    x = MARGINS(1);
    y = H - MARGINS(4) - editSize(2);
    
    
  % % Create components
    
    hEdit = uicontrol(hPanel, 'Style', 'edit');
    hEdit.Position = [x, y, editSize];
    hEdit.HorizontalAlignment = 'left';

    y = MARGINS(2); 
    listboxSize = [editSize(1), componentHeight - editSize(2) - SPACING(2)];

    hLBox = uicontrol(hPanel, 'Style', 'listbox');
    hLBox.Position = [x, y, listboxSize];
    %hLBox.BackgroundColor = bgColor;
    hLBox.Max = 2;
    hLBox.String = listIn;

    x = x + editSize(1) + SPACING(1);
    y = H - MARGINS(4) - buttonSize(2);

    %hButtons = uim.control.Button_.empty;
    hButtons = gobjects(1, numButtons);

    for i = 1:numButtons

        hButtons(i) = uicontrol(hPanel, 'Style', 'pushbutton');
        hButtons(i).String = buttonNames{i};

        %hButtons(i) = uim.control.Button_(hPanel, 'Text', buttonNames{i});
        hButtons(i).Position = [x, y, buttonSize];
        %hButtons(i).HorizontalTextAlignment = 'center';
        %hButtons(i).FontSize = 12;

        y = y - SPACING(2) - buttonSize(2);

    end

    % Assign callback when all buttons are created
    for i = 1:numButtons
        hButtons(i).Callback = @(s,e,h1,h2,h3) onButtonPressed(s,hEdit,hLBox,hButtons);
    end


    buttonSize = [100, 18];

    x = f.Position(3)/2 + [-1,1]*SPACING(1)/2 + [-1, 0]*buttonSize(1);
    y = MARGINS(4);

    buttonNames = {'Save', 'Cancel'};
    count = i;
    for i = 1:2
        hButtons(count+i) = uicontrol(hPanel, 'Style', 'pushbutton');
        hButtons(count+i).String = buttonNames{i};
        hButtons(count+i).Position = [x(i), y, buttonSize];
        hButtons(count+i).Callback = @quit;
    end


    h = applify.uicontrolSchemer([hButtons, hEdit, hLBox]);


    jLBox = findjobj(hLBox);
    javacolor = @javax.swing.plaf.ColorUIResource;
    jColor = javacolor(bgColor(1), bgColor(2), bgColor(3));
    newBorder = javax.swing.BorderFactory.createLineBorder(jColor, 0);
    jLBox.setBorder(newBorder)

    
    
    hLBox.ForegroundColor = params.Theme.FigureFgColor;
    hEdit.ForegroundColor = params.Theme.FigureFgColor;
    hLBox.BackgroundColor = bgColor;
    hEdit.BackgroundColor = bgColor;
    
    set(hLBox, 'FontSize', 12)
    set(hButtons, 'FontSize', 12)
    
    delete(tmpPanel)
    
    uiwait(f)
    
    if ~isvalid(f); listOut = []; return; end
    
    switch f.UserData.Mode
        case 'Save'
            listOut = hLBox.String;
        case 'Cancel'
            listOut = originalList;
    end
    
    delete(f)
    delete(h)

end



function onButtonPressed(src, hEdit, hLBox, hButtons)
    
    
    if isempty(hLBox.String) && ismember(src.String, {'Edit', 'Remove', 'Move Up', 'Move Down'})
        return
    end


    switch src.String
        case 'Add'
            if ~isempty(hEdit.String)
                hLBox.String{end+1} = hEdit.String;
                if numel(hLBox.String) == 1
                    hLBox.Value = 1;
                end
                hEdit.String = '';
            end
            
        case 'Remove'
            hLBox.String(hLBox.Value) = [];
            if hLBox.Value > numel(hLBox.String)
                hLBox.Value = hLBox.Value-1;
            end
            
        case 'Edit'
            hEdit.String = hLBox.String{hLBox.Value};
            src.String = 'Finish';
            hLBox.Enable = 'off';
            set(hButtons, 'Enable', 'off')
            src.Enable = 'on';
            
        case 'Finish'
            hLBox.String{hLBox.Value} = hEdit.String;
            hEdit.String = '';
            src.String = 'Edit';
            hLBox.Enable = 'on';
            set(hButtons, 'Enable', 'on')
            
        case 'Move Up'
            IND = 1:numel(hLBox.String);
            flipInd = hLBox.Value - fliplr(0:1);
            
            if hLBox.Value > 1
                IND(flipInd) = IND(fliplr(flipInd));
                hLBox.String = hLBox.String(IND);
                hLBox.Value = hLBox.Value-1;
            end
            
        case 'Move Down'
            IND = 1:numel(hLBox.String);
            flipInd = hLBox.Value + (0:1);
            
            if hLBox.Value < numel(hLBox.String)
                IND(flipInd) = IND(fliplr(flipInd));
                hLBox.String = hLBox.String(IND);
                hLBox.Value = hLBox.Value+1;
            end
    end
end


function quit(src, ~)
    f = ancestor(src, 'figure');
    f.UserData.Mode = src.String;
    uiresume(f)
end