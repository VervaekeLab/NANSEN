function jhUic = findJavaComponents(hUic, hParent)
%findUicJobj Find java objects of uicontrols in a figure panel
%
%    jhUic = findUicJobj(hUic, hParent) return a cell array of java objects
%    given an array og uicontrol objects and a panel they belong to.
%
%    Inspired by Yair Altmans findjobj, but specialized for the purpose of
%    finding uicontrols in a specific panel container.

    %% Find java handle of parent container Credit: findjobj @ Yair Altman
    try     jContainer = hParent.JavaFrame.getGUIDEView;
    catch,  jContainer = [];
    end

    if isempty(jContainer)
        hFig = ancestor(hUic(1), 'figure');
        jf = get(hFig, 'JavaFrame');
        jContainer = jf.getFigurePanelContainer.getComponent(0);
    end
    
    % Force an EDT redraw before processing, to ensure all uicontrols etc. are rendered
    drawnow;  pause(0.02);
    
    %% Find handle of 'com.mathworks.hg.peer.FigureComponentContainer'
    % which contains the uicontrols and the underlying java handles
    
    isa(jContainer, 'com.mathworks.hg.peer.ui.UIPanelPeer$UIPanelJPanel');
%     jContainer.getComponentCount = 1
    
    jContainer1A = jContainer.getComponent(0);
    isa(jContainer1A, 'com.mathworks.hg.peer.HeavyweightLightweightContainerFactory$FigurePanelContainerLight');
%     jContainer1A.getComponentCount = 2;
    
    jContainer2A = jContainer1A.getComponent(0); % com.mathworks.hg.peer.FigureComponentContainer
%     jContainer2B = jContainer1A.getComponent(1); % 'com.mathworks.hg.peer.JavaSceneServerGLJPanel'
    
    numUicHandles = numel(hUic);
    numComponents = jContainer2A.getComponentCount; % Should be equal or higher than numel hUic
    
    %% Match java components with uicontrol handles
    
    % Use same strategy as Yair Altman's findjobj (setting tooltip prop)
    
    try  % Fix for R2018b suggested by Eddie (FEX comment 2018-09-19)
        tooltipPropName = 'TooltipString';
    catch
        tooltipPropName = 'Tooltip';
    end
    
    tooltips = struct;
    assert(numUicHandles < 9999);
    
    for i = 1:numUicHandles
        tooltips(i).old = get(hUic(i), tooltipPropName);
        tooltips(i).tmp = sprintf('@&#%04d', i);
        set(hUic(i), tooltipPropName, tooltips(i).tmp);
    end
    
    allToolTips = {tooltips.tmp};
    jhUic = cell(numUicHandles, 1);
    
    finished = false;
    count = 40;
    nFound = 0;
    
    while ~finished && count>0
        pause(0.005); count = count-1;
        
        for j = numComponents:-1:1 % Start from newest controls...
            jCompTmp = jContainer2A.getComponent(j-1).getComponent(0);
            tooltipStr = jCompTmp.getToolTipText;
            tooltipStr = char(tooltipStr);
            
            if ~isempty(tooltipStr)
                isMatch = contains(allToolTips, char(tooltipStr));
                if sum(isMatch) == 0
                    % Continue
                elseif sum(isMatch) == 1
                    jhUic{isMatch} = jCompTmp;
                    nFound = nFound + sum(isMatch);
                else
                    error('Please debug')
                end
            end
            
            if nFound == numUicHandles
                finished = true;
            end
            
            drawnow

        end
    end
    
    % Reset tooltip
    for i = 1:numUicHandles
        set(hUic(i), tooltipPropName, tooltips(i).old);
    end
end
