function createColormapList(hMenu, hAxes, varargin)
%createColormapList Create a list of colormaps in a menu.
%
%   createColormapList(hMenu, hAxes)
%

% TODO: Should take a list of colormaps as an input, and only show the
% colormaps in that list.

    def = struct('Separator', 'off');
    opt = utility.parsenvpairs(def, [], varargin);
        
    mitem = uimenu(hMenu, 'Label', 'Set Colormap', 'Separator', opt.Separator);
        colormapNames = {'Viridis', 'Inferno', 'Magma','Plasma', 'jet', 'Nissl', ...
            'BuPu', 'GnBu', 'Greens', 'PuBuGn', 'YlOrRd', 'PuOr', 'Gray', ...
            'thermal', 'haline', 'solar', 'ice', 'gray', 'oxy', 'deep', 'dense', ...
            'algae','matter','turbid','speed', 'amp','tempo' };
        for i = 1:numel(colormapNames)
            tmpItem = uimenu(mitem, 'Label', colormapNames{i});
            tmpItem.Callback = @(src, event) changeColormap(src, event, hAxes);
        end
    end
    
function changeColormap(src, ~, hAxes)
            
    switch src.Label
        case 'Viridis'
            cmap = viridis;
        case 'Inferno'
            cmap = inferno;
        case 'Magma'
            cmap = magma;
        case 'Plasma'
            cmap = plasma;
        case 'jet'
            cmap = jet(255);
        case 'Nissl'
            cmap = fliplr(cbrewer('seq', 'BuPu', 256));
        case 'BuPu'
            cmap = cbrewer('seq', 'BuPu', 256);
        case 'PuBuGn'
            cmap = flipud(cbrewer('seq', src.Label, 256));
        case {'GnBu', 'Greens', 'YlOrRd'}
            cmap = cbrewer('seq', src.Label, 256);
        case 'PuOr'
            cmap = flipud(cbrewer('div', src.Label, 256));
        case 'Gray'
            cmap = gray(256);
        case {'thermal', 'haline', 'solar', 'ice', 'gray', 'oxy', 'deep', 'dense', ...
        'algae','matter','turbid','speed', 'amp','tempo'}
            cmap = cmocean(src.Label);
    end

%             cmap(1, :) = [0.7,0.7,0.7];%obj.fig.Color;
    colormap(hAxes, cmap)

end
