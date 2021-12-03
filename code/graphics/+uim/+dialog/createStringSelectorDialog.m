function IND = createStringSelectorDialog(inputString, refPosition)
%createStringSelectorDialog Create a dialog box for selecting substring
%
%   IND = createStringSelectorDialog(INPUTSTRING) returns the index 
%   positions (IND) which a user selects from the string (INPUTSTRING).
%
%   IND = createStringSelectorDialog(INPUTSTRING, REFPOSITION) opens the
%   dialog box (figure) relative to a reference position.

% TODO: Create a widget for this..

IND = [];

if nargin < 2; refPosition = []; end


%% Create figure
%f = uifigure() %'WindowStyle', 'modal'); slower
f = figure('MenuBar', 'none', 'WindowStyle', 'modal');

f.Name = 'Select letters from given text';
f.NumberTitle = 'off';


%% Configure layout (adapt figure size to components)
numChars = numel(inputString);

componentMargins = [10,10,10,15]; % Margin for toolbar/strip with letters
buttonSize = [18,22];   % Buttonsize for buttons with individual letters

minFigureWidth = 240; % Based on size on positioning of ok and cancel button.

buttonStripWidth = (buttonSize(1)+2) * numChars;

figSize = [buttonStripWidth + sum( componentMargins([1,3]) ), ...
    buttonSize(2) + sum( componentMargins([2,4]) )];

figSize(2) = figSize(2)+ 45; % expand to make space for ok and cancel buttons
if figSize(1) < minFigureWidth
    figSize(1) = minFigureWidth; 
    componentMargins([1,3]) = (minFigureWidth - buttonStripWidth) / 2;
end

f.Position(3:4) = figSize;
f.Resize = 'off';


% Center figure on screen
screenSize = get(0, 'ScreenSize');
figLoc = screenSize(1:2) + (screenSize(3:4) - figSize) / 2;

if ~isempty(refPosition)
    f.Position(1:2) = refPosition(1:2) + (refPosition(3:4) - figSize)/2;
else
    f.Position(1:2) = figLoc;
end

drawnow

%% Create toolbar and buttons for each letter
hToolbar = uim.widget.toolbar_(f, 'Spacing', 2, 'BackgroundAlpha',0, ...
    'Margin', componentMargins, 'Padding', [0,0,0,0] );

for i = 1:numel(inputString)
    
    letter = inputString(i);
    
    hToolbar.addButton('Text', letter, 'Mode', 'togglebutton', ...
        'MechanicalAction', 'Switch when pressed', 'Size', buttonSize, ...
        'Style', uim.style.buttonLetterSelection, 'CornerRadius', 0, 'FontSize', 12, ...
        'HorizontalTextAlignment', 'center', 'Padding', [0,0,0,0], ...
        'VerticalTextALignment', 'middle', ...
        'Callback', @(src, evt, hTB) onLetterSelected(src, evt, hToolbar) )
    
end

% % buttonOk = uim.control.Button_(f, 'Position', [200, 20, 100,24], 'Size', [100,26], 'PositionMode', 'manual', 'SizeMode', 'manual', 'Text', 'Ok', 'Style', uim.style.buttonLightMode);
% % buttonCancel = uim.control.Button_(f, 'Position', [40, 20, 100,24], 'PositionMode', 'manual', 'SizeMode', 'manual', 'Text', 'Cancel', 'Style', uim.style.buttonLightMode);

%% Create ok and cancel buttons.

buttonSize = [80,25]; % Buttons size for ok and cancel buttons.
xLoc1 = f.Position(3)/2 - buttonSize(1)-20;
xLoc2 = f.Position(3)/2 + 20;

if isuifigure(f)
    buttonOk = uibutton(f, 'Text', 'Ok', 'Position', [xLoc1, 20 ,buttonSize] );
    buttonCancel = uibutton(f, 'Text', 'Cancel', 'Position', [xLoc2, 20,buttonSize] );

    buttonOk.ButtonPushedFcn = @closeStringSelectorDialog;
    buttonCancel.ButtonPushedFcn = @closeStringSelectorDialog;

elseif isa(f, 'matlab.ui.Figure')
    buttonOk = uicontrol(f, 'style', 'pushbutton', 'String', 'Ok', 'Position', [xLoc1, 10 ,buttonSize] );
    buttonCancel = uicontrol(f, 'style', 'pushbutton', 'String', 'Cancel', 'Position', [xLoc2, 10,buttonSize] );

    buttonOk.Callback = @closeStringSelectorDialog;
    buttonCancel.Callback = @closeStringSelectorDialog;
    
    h = uicontrol(f, 'style', 'text', 'Position', [10,figSize(2)-20,300,18]);
    h.String = 'Tip: Use shift to select multiple letters';
    h.FontSize = 12;
    h.HorizontalAlignment = 'left';
    
end

f.UserData.ExitMode = 'Cancel';
f.UserData.PrevSelectedIndex = [];

uiwait(f)


% Return indices of selected letters if ok button was pressed
if isvalid(f) && strcmp(f.UserData.ExitMode, 'Finish')
    buttons = hToolbar.Children;
    isSelected = arrayfun(@(btn) btn.Value, buttons, 'uni', 1);
    IND = find(isSelected);
end

if isvalid(f)
    close(f)
end


end



function closeStringSelectorDialog(src, event)
    
    hFig = ancestor(src, 'figure');
    
    if isuifigure(hFig)
        switchExpression = 'Text';
    else
        switchExpression = 'String';

    end
    
    
    switch src.(switchExpression)
        case 'Ok'
            hFig.UserData.ExitMode = 'Finish';
        case 'Cancel'
            hFig.UserData.ExitMode = 'Cancel';
    end
    uiresume(hFig)
end


function onLetterSelected(src, ~, hToolbar)
    
    hFig = ancestor(src.Parent, 'figure');
    buttons = hToolbar.Children;
    currentInd = find(ismember(buttons, src));
    
    switch hFig.SelectionType
        case 'normal'
            hFig.UserData.PrevSelectedIndex = currentInd;
            
        case 'extend'
            if isempty(hFig.UserData.PrevSelectedIndex)
                hFig.UserData.PrevSelectedIndex = currentInd;
            else
                
                prevInd = hFig.UserData.PrevSelectedIndex;
                
                for i = prevInd:currentInd
                    buttons(i).Value = true;
                end
                
                hFig.UserData.PrevSelectedIndex = currentInd;
            end
             
    end
    
end


function tf = isuifigure(h)

% Credit: Adam Danz @
% https://www.mathworks.com/matlabcentral/answers/348387-distinguish-uifigure-from-figure-programmatically

    if verLessThan('Matlab','9.0')      %version < 16a (release of uifigs)
        isuifig = @(~)false;
    elseif verLessThan('Matlab','9.5')  % 16a <= version < 18b 
        isuifig = @(h)~isempty(matlab.ui.internal.dialog.DialogHelper.getFigureID(h));
    else                                % version >= 18b (written in r21a)
        isuifig = @(h)matlab.ui.internal.isUIFigure(h);
    end
    
    tf = isuifig(h); 

end