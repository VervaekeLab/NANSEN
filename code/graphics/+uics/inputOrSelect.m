function selectedValue = inputOrSelect(listIn, varargin)
%inputOrSelect Dialog for entering a value manually or select from a list
    
    params = struct();
    params.Title = '';
    params.Theme = nansen.theme.getThemeColors('dark-purple');
    params.ReferencePosition = [];
    params.ItemName = 'value';
    params.FontSize = 13;
    
    params = utility.parsenvpairs(params, 1, varargin{:});

    if nargin < 1
        listIn = {};
    end
    
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
    
    
  % % Configure layout of components
    buttonSize = [80, 18];
    
    editSize = [160, 20];
   
    componentWidth = editSize(1);
    componentHeight = 225;
    
    f.Position(3:4) = [componentWidth, componentHeight] + sum(MARGINS([1,2;3,4]));
    H = f.Position(4); % Figure Height
    
    if ~isempty(params.ReferencePosition)
        uim.utility.layout.centerObjectInRectangle(f, params.ReferencePosition)
    end
     
    x = MARGINS(1);
    y = H - MARGINS(4) - editSize(2);
    
  % % Create components
  
    hLabelEdit = uicontrol(hPanel, 'Style', 'text');
    hLabelEdit.String = sprintf('Enter a %s...', params.ItemName);
    hLabelEdit.Position = [x, y, editSize];
    hLabelEdit.HorizontalAlignment = 'left';

    y = y - editSize(2) - SPACING(2)/3;

    hEdit = uicontrol(hPanel, 'Style', 'edit');
    hEdit.Position = [x, y, editSize];
    hEdit.HorizontalAlignment = 'left';

    y = y - editSize(2) - SPACING(2)/2;

    hLabelSelect = uicontrol(hPanel, 'Style', 'text');
    hLabelSelect.String = '... Or select from list';
    hLabelSelect.Position = [x, y, editSize];
    hLabelSelect.HorizontalAlignment = 'left';

    listboxHeight = y - MARGINS(2) - SPACING(2)/3;
    listboxSize = [editSize(1), listboxHeight];
    %listboxSize = [editSize(1), componentHeight - editSize(2) - SPACING(2)];
    
    y = MARGINS(2); 
    hLBox = uicontrol(hPanel, 'Style', 'listbox');
    hLBox.Position = [x, y, listboxSize];
    %hLBox.BackgroundColor = bgColor;
    hLBox.Min = 0;
    hLBox.Max = 1;
    hLBox.String = [{'Use text input'}, listIn];
    hLBox.Value = 1;


    x = x + editSize(1) + SPACING(1);
    y = H - MARGINS(4) - buttonSize(2);

    %hButtons = uim.control.Button_.empty;
    hButtons = gobjects(1, 2);

    % Create finish buttons
    buttonWidth = (f.Position(3) - sum(MARGINS([1,3])) - SPACING(1)) / 2;
    buttonSize = [buttonWidth, 18];


    x = f.Position(3)/2 + [-1,1]*SPACING(1)/2 + [-1, 0]*buttonSize(1);
    y = MARGINS(4);

    buttonNames = {'Ok', 'Cancel'};
    count = 0;
    for i = 1:2
        hButtons(count+i) = uicontrol(hPanel, 'Style', 'pushbutton');
        hButtons(count+i).String = buttonNames{i};
        hButtons(count+i).Position = [x(i), y, buttonSize];
        hButtons(count+i).Callback = @quit;
    end

    hLabels = [hLabelEdit, hLabelSelect];
    
    warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved')
    h = applify.uicontrolSchemer([hButtons, hEdit, hLBox, hLabels]);
    warning('on', 'MATLAB:ui:javaframe:PropertyToBeRemoved')

    jLBox = findjobj(hLBox);
    javacolor = @javax.swing.plaf.ColorUIResource;
    jColor = javacolor(bgColor(1), bgColor(2), bgColor(3));
    newBorder = javax.swing.BorderFactory.createLineBorder(jColor, 0);
    jLBox.setBorder(newBorder)

    hLBox.ForegroundColor = params.Theme.FigureFgColor;
    hEdit.ForegroundColor = params.Theme.FigureFgColor;
    hLBox.BackgroundColor = bgColor;
    hEdit.BackgroundColor = bgColor;
    
    set(hLabels, 'ForegroundColor', params.Theme.FigureFgColor, 'FontSize', params.FontSize-1)
    set([hLBox, hEdit, hButtons], 'FontSize', params.FontSize)
    
    delete(tmpPanel)
    
    uiwait(f)
    
    if ~isvalid(f); selectedValue = []; return; end
    
    switch f.UserData.Mode
        case 'Ok'
            if hLBox.Value == 1
                if ~isempty(hEdit.String)
                    selectedValue = hEdit.String;
                else
                    selectedValue = [];
                end

            elseif hLBox.Value ~= 1
                selectedValue = hLBox.String{hLBox.Value};
            else
                selectedValue = [];
            end
            
        case 'Cancel'
            selectedValue = [];
    end
    
    delete(f)
    delete(h)
end

function quit(src, ~)
    f = ancestor(src, 'figure');
    f.UserData.Mode = src.String;
    uiresume(f)
end