classdef InjectionSpot < fovmanager.mapobject.BaseObject
    
%     injectionVolume in nanoliters
%     r = nthroot(injectionVolume * 1e6 * 3/(4*pi), 3); r in um.


properties (Constant, Transient)
    virusGDocId = '1te_CKmnTH1naKTsiM0BYB0ivZ7mzZkFBiFj6EELgiqI'
end


properties 
    name    % name of virus.
    color   % color of virus. will show on map and be saved in inventory
    
    spread  % in micrometers
    volume  % in nanoliters
    
    depth   % in micrometers
    
end


properties (Transient)
   boundaryWidth = 1;
   boundaryColor = 'none';
end


methods
    
    function obj = InjectionSpot(varargin)
%         position, name, volume, depth, spread

        if isa(varargin{1}, 'fovmanager.App')
            fmHandle = varargin{1};
            varargin = varargin(2:end);
        end

        
        if isa(varargin{1}, 'struct')
            obj.fromStruct(varargin{1})
        else
            % Assume 1st argument is a position vector
            validateattributes(varargin{1}, {'numeric'}, {'numel', 2})
            centerPosition = varargin{1};
            
            obj.center = centerPosition;
            obj.shape = 'sphere';
            
            % Assume 2nd argument is a name argument
            validateattributes(varargin{2}, {'char'}, {'scalartext'});
            obj.name = varargin{2};
            
            % Assume 3rd argument is a volume argument
            validateattributes(varargin{3}, {'numeric'}, {'nonnan', 'numel', 1});
            obj.volume = varargin{3};
            
            % Assume 4th argument is a depth argument
            validateattributes(varargin{4}, {'char'}, {'scalartext'});
            obj.depth = varargin{4};
            
            % Assume 5th argument is ...
            validateattributes(varargin{5}, {'numeric'}, {'numel', 1});
            obj.spread = varargin{5};
            
            if isnan(obj.spread)
                obj.spread = nthroot(obj.volume * 1e6 * 3/(4*pi), 3);
            end
        end
        
        [x, y] = obj.getBoundaryCoordinates();
        obj.edge = [x, y];
        

        if exist('fmHandle', 'var')
            obj.displayObject(fmHandle)
        end

    end
    
    
    function fromStruct(obj, S)

        % Keep this for now, because some spots might be saved with virusGDocId
        % property. In general, i need some more tests in the fromStruct,
        % to avoid setting properties that are discontinued, or like in this
        % case, constant
        
        fields = fieldnames(S);
        for i = 1:numel(fields)
            if strcmp(fields{i}, 'virusGDocId')
                continue
            end
            obj.(fields{i}) = S.(fields{i});
        end

    end
    
    
    function displayName = getDisplayName(obj, keyword) %#ok<MANU>
        
        if nargin < 2; keyword = ''; end
        
        switch keyword
            case 'class'
                displayName = utility.string.varname2label(class(obj));
                displayName = strrep(displayName, 'fovmanager.mapobject.', '');
            otherwise
                displayName = 'Injection';
        end
    end
    
    
% % Context menu on the gui object in fov manager

    function createContextMenu(obj, fmHandle)

        m = uicontextmenu;
        
        mitem = uimenu(m, 'Text', 'Set Color');
        
        alternatives = {'Red', 'Green', 'Blue', 'Yellow'};
        for i = 1:numel(alternatives)
            tmpItem = uimenu(mitem, 'Text', alternatives{i});
            tmpItem.Callback = {@obj.changeColor, alternatives{i}};
        end

        mitem = uimenu(m, 'Text', 'Edit Injection Volume');
        mitem.Callback = {@obj.requestPropertyChange, 'volume'};

        mitem = uimenu(m, 'Text', 'Edit Estimated Spread');
        mitem.Callback = {@obj.requestPropertyChange, 'spread'};
        
        mitem = uimenu(m, 'Text', 'Edit Injection Depth');
        mitem.Callback = {@obj.requestPropertyChange, 'depth'};
        
        if obj.isMovable
            mitem = uimenu(m, 'Text', 'Lock Position', 'Separator', 'on');
        else
            mitem = uimenu(m, 'Text', 'Unlock Position', 'Separator', 'on');
        end
        mitem.Callback = @obj.togglePositionLock;

        mitem = uimenu(m, 'Text', 'Delete Injection');
        mitem.Callback = @obj.requestdelete;

        obj.guiHandle.UIContextMenu = m;

    end
        
     
    function requestPropertyChange(obj, ~, ~, propertyName)
        
        requestMsg = sprintf('Enter new value for %s', propertyName);
        answer = inputdlg(requestMsg);
        if isempty(answer); return; end
        
        switch propertyName
            case 'volume'
                obj.volume = str2double(answer{1});
            case 'depth'
                obj.depth = answer{1};
            case 'spread'
                obj.spread = str2double(answer{1});
                obj.plotBoundary()
        end
        
        
    end
    
    
% % Plot methods
    
    function [x, y] = getBoundaryCoordinates(obj)
    
        theta = linspace(0,2*pi,200);
        rho = ones(size(theta)) .* (obj.spread/1000);
        
        [x, y] = pol2cart(theta, rho);

        x(end+1)=x(1);
        y(end+1)=y(1);
        
        % Transpose to outpot column vectors.
        x = x' + obj.center(1);
        y = y' + obj.center(2);
        
    end


    function changeColor(obj, ~, ~, color)
        
        obj.color = lower(color(1));
        
        hTmp = findobj(obj.guiHandle, 'Tag', 'Injection Spot');
        set(hTmp, 'FaceColor', obj.color)
        
    end
    
    
    function infoText = getInfoText(obj)
        
        infoText = '';

        if ~isempty(obj.name)
            infoText = sprintf('Virus Name: %s\n', round(obj.name));
        end

        if ~isempty(obj.volume)
            infoText = sprintf('%sVolume: %d nL\n', infoText, obj.volume);
        end
        
        if ~isempty(obj.depth)
            infoText = sprintf('%sDepth: %sum', infoText, obj.depth);
        end
        

        if ~isempty(infoText) && isequal(double(infoText(end)), 10) % 10 is the newline character
            infoText = infoText(1:end-1);
        end

%         hTxt.String = infoText;
        
    end
    

    function fliplr(obj)
        % not implemented
    end
    
    
    function flipud(obj)
        % not implemented
    end
    
    
    function rotate(obj)
        % not implemented
    end
    
end


methods (Access = protected)
          
    % Todo: make refresh method.....

    function plotBoundary(obj)

        [x, y] = obj.getBoundaryCoordinates();
        
        h1 = findobj(obj.guiHandle, 'Tag', 'Injection Outline');
        
        if isempty(h1)
            h1 = plot(obj.guiHandle, x+obj.center(1), y+obj.center(2), 'k'); 
            h1.Color = 'none';
            h1.Tag = 'Injection Outline';
        else
            set(h1, 'XData', x+obj.center(1), 'YData', y+obj.center(2))
        end

        
        % Following requires row vectors where center is subtracted...
        x = transpose(x - obj.center(1));
        y = transpose(y - obj.center(2));
        
        x = cat(2, x, fliplr(x)*0) + obj.center(1);
        y = cat(2, y, fliplr(y)*0) + obj.center(2);
        
        alpha = zeros(size(x));
        alpha(ceil(numel(x)/2):end) = 0.8;
        if isempty(obj.color)
            obj.color = 'c';
        end
        
        h2 = findobj(obj.guiHandle, 'Tag', 'Injection Spot');
        
        if isempty(h2)
            h2 = patch(obj.guiHandle, x, y, obj.color); 
            h2.FaceVertexAlphaData = alpha';
            h2.FaceAlpha = 'interp';
            h2.EdgeColor = 'none';

            h2.Tag = 'Injection Spot';
            h2.PickableParts = 'visible';
            h2.HitTest = 'off';
            uistack(h2, 'top')
        else
            set(h2, 'XData', x, 'YData', y)
        end
        
    end
    
end
    

methods (Static)
    
    
    function virusNames = retrieveVirusNames()
    
        % Get list of viruses from the current google doc virus list
        docid = fovmanager.mapobject.InjectionSpot.virusGDocId;
        result = fovmanager.utility.atlas.GetGoogleSpreadsheet(docid); %% <-- FileExchange

        % Replace empty cells with empty string
        for i = 1:numel(result)
            if isempty(result{i})
                result{i} = '';
            end
        end
        
        % Assume structure of document does not change too much, and find 
        % column and first row element of the virus names.
        [firstRow, col] = find(strcmp(result, 'Virus'));
        virusNames = result(firstRow+1:end, col);
        isEmptyCell = cellfun(@(c) isempty(c), virusNames);
        virusNames(isEmptyCell)=[];
        virusNames = unique(virusNames);
        
    end
    
    
    function answers = requestVirusInfo()
        % What a big mess for so little ......
        
        try
            virusNames = fovmanager.mapobject.InjectionSpot.retrieveVirusNames();
        catch
            virusNames = '';
            
        end
        [figH, EditHandle] = fovmanager.widget.inputdlg2({'Enter Number of Injections', ...
            'Enter Name of Virus', ...
            'Enter Volume (nL, can change later)', ...
            'Enter Depth (um, optional)', ...
            'Spread (radius in um, optional)'});
        
        if ~isempty(virusNames)
            % Replace 2nd editHandle with searchAutocomplete...
            set(EditHandle(2), 'Units', 'normalized')
            pos = EditHandle(2).Position;

            autoWidget = fovmanager.widget.searchAutoCompleteInputDlg(figH, virusNames, 'Position', pos, 'TextPrompt', 'Search For Virus');
        end
        
        uiwait(figH)

        % Check handle validity again since we may be out of uiwait because the
        % figure was deleted.
        if ishghandle(figH)
          answers={};
          if strcmp(get(figH,'UserData'),'OK'),
              NumQuest = 5;
            answers=cell(NumQuest,1);
            for lp=1:NumQuest,
              answers(lp)=get(EditHandle(lp),{'String'});
            end
            if ~isempty(virusNames)
                answers{2} = autoWidget.getAnswer;
            end
          end
          delete(figH);
        else
          answers={};
        end
        drawnow; % Update the view to remove the closed figure (g1031998)

    end
    

end

        
end
