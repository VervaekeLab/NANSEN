function createQuickZoomLabels(parent, numFrames, callbackFcn, options)


    uicc = uim.UIComponentCanvas(parent);

    newButtonSize = [50, 15];

    % Create a toolbar for app-related buttons in upper right corner.
    hAppbar = uim.widget.toolbar(uicc, 'Location', 'northeast', ...
        'ComponentAlignment', 'right', ...
        'BackgroundColor', ones(1,3)*0.5, ...
        'BackgroundAlpha', 0, 'Size', [200, 20], ...
        'IsFixedSize', [false, true], ...
        'NewButtonSize', newButtonSize, ...
        'Margin', [10,10,10,10], 'Padding', [5,5,5,5], 'Spacing', 0, ...
        'CornerRadius', 5, 'BorderColor', 'none');

    %hAppbar.Orientation = 'vertical'

    buttonArgs = {'Padding', [0,0,0,0], 'Style', uim.style.textLabel, ...
        'CornerRadius', 0};

    hBtn = uim.control.Button.empty;
    
    
    minNumber = min([100, numFrames/10]);
    
    numFrames = log(numFrames);
    minFrames = log(minNumber);
    labels = linspace(minFrames, numFrames, 5);
    labels = exp(labels);
    labels = round(labels, -2);
    
    labels = arrayfun(@(i) num2str(i), labels, 'uni', 0);
    labels{end} = 'all';
    
    for i = 1:numel(labels)
        hBtn(i) = hAppbar.addButton('String', labels{i}, ...
            'Padding', [0,0,0,0], ...
            'ButtonDownFcn', @(s,e,m) disp('test click'), ...
            'Type', 'togglebutton', buttonArgs{:});
       
    end

    for i = 1:numel(labels)
        %hBtn(i).ButtonDownFcn = @(s,e,h,ind) onLabelPressed(s, hBtn, i);
        hBtn(i).ButtonDownFcn = @(s,e,h,ind) callbackFcn(s,hBtn,i);
    end

end

function onLabelPressed(src, hBtn, i)
           
    if src.Value

        for iBtn = 1:numel(hBtn)
            if iBtn ~= i
                hBtn(iBtn).Value = false;
            end
        end
    else
        hBtn(end).Value = true;
    end
    
end