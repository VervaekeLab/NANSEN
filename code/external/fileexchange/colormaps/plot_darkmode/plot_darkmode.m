function  plot_darkmode(varargin)
% The function generates from a Matlab plot figure a version that can be
% copied to a dark mode theme presentation or website.
% The function replaces the default texts and box colors to
% a user input color (default is white), and make the plot area transparent
% to accept the dark background below it. The function also transform the
% graphic colors that are not appropriate (low contrast) for a dark mode
% theme to a version that is dark theme legible using a desaturation and
% brightness approach.
%
% preparing this function I was inspired by https://material.io/design/color/dark-theme.html
%
% The function is a work in progess and may not support all figure objects


%  Inputs:
%  varargin(1)- The text color to modify (default is white)
%  varargin(2)- The threshold from which to apply the cotrast correction (default is 4.5)
%  varargin(3)- The dark background  (default is gray of value 0.16)
%
%
%  How to the function:
%  generate or import a Matlab figure and run the function:
%
%       plot(bsxfun(@times,[1:4],[2:5]'));xlabel('X');ylabel('Y');
%       plot_darkmode
%
%  next copy the figure from the clipboard using Edit>Copy Figure and
%  paste it on top of the dark background theme, for example in
%  PowerPoint. Make sure that in the Copy Option, the  Transparent
%  Background is enabled


%   Ver 1.02 (2021-09-28)
%   Adi Natan (natan@stanford.edu)

%% defaults
switch nargin
    case 3
        textcolor=varargin{1};
        contrast_ratio=varargin{2};
        dark_bkg_assumption=varargin{3};
    case 2
        textcolor=varargin{1};
        contrast_ratio=varargin{2};
        dark_bkg_assumption= ones(1,3)*0.16;
    case 1
        textcolor=varargin{1};
        contrast_ratio=4.5;
        dark_bkg_assumption= ones(1,3)*0.16;
    otherwise
        textcolor=[1,1,1];
        contrast_ratio=4.5;
        dark_bkg_assumption= ones(1,3)*0.16;
end

tcd = [{textcolor} , {contrast_ratio} , {dark_bkg_assumption}];



g = get(get(gcf,'children'),'type');
if ~strcmp(g,'tiledlayout')
    h = get(gcf,'children');
    axes_ind      =  findobj(h,'type','Axes');
    legend_ind    =  findobj(h,'type','Legend');
    colorbar_ind  =  findobj(h,'type','Colorbar');
else
    h0= get(gcf,'children');
    h0.Title.Color    =  textcolor;
    h0.Subtitle.Color =  textcolor;
    
    h=get(get(gcf,'children'),'children');
    
    axes_ind      =  findobj(h,'type','Axes');
    legend_ind    =  findobj(h,'type','Legend');
    colorbar_ind  =  findobj(h,'type','Colorbar');
   
end


%% modify Axes
for n=1:numel(axes_ind)
    
    % edit x-ticks color
    for m=1:numel(axes_ind(n).XTickLabel)
        axes_ind(n) .XTickLabel{m} = ['\color[rgb]' sprintf('{%f,%f,%f}%s',textcolor)    axes_ind(n) .XTickLabel{m} ];
    end
    
    % edit y-ticks color
    for m=1:numel( axes_ind(n).YTickLabel)
        axes_ind(n).YTickLabel{m} = ['\color[rgb]' sprintf('{%f,%f,%f}%s',textcolor)    axes_ind(n).YTickLabel{m} ];
    end
    
    axes_ind(n) .Color        = tcd{3};% 'none';    % make white area transparent
    axes_ind(n).XColor       = textcolor; % edit x axis color
    axes_ind(n).YColor       = textcolor; % edit y axis color
    axes_ind(n).ZColor       = textcolor; % edit z axis color
    
    axes_ind(n).XLabel.Color = textcolor; % edit x label color
    axes_ind(n).YLabel.Color = textcolor; % edit y label color
    axes_ind(n).ZLabel.Color = textcolor; % edit z label color
    
    axes_ind(n).Title.Color  = textcolor; % edit title text color
    
    axes_ind(n).GridColor =  adjust_color( axes_ind(n).GridColor,tcd);
    axes_ind(n).MinorGridColor =  adjust_color(axes_ind(n).MinorGridColor,tcd);
    % axes_ind(n).Subtitle.Color = textcolor;
    
    % take care of other axes children:
    h2 = get(axes_ind(n),'Children');
    g2 = get(axes_ind(n).Children,'type');
    text_ind  = find(strcmp(g2,'text'));
    patch_ind = find(strcmp(g2,'patch'));
    line_ind  = find(strcmp(g2,'line'));
    errorbar_ind = find(strcmp(g2,'errorbar'));
    area_ind  = find(strcmp(g2,'area'));
    bar_ind  = find(strcmp(g2,'bar'));
    hist_ind = find(strcmp(g2,'histogram'));
    % contour_ind  = find(strcmp(g2,'contour'));
    % surface_ind = find(strcmp(g2,'surface'));
    
    % edit texts color
    for m=1:numel(text_ind)
        h2(text_ind(m)).Color=adjust_color( h2(text_ind(m)).Color ,tcd);
        if ~strcmp( h2(text_ind(m)).BackgroundColor,'none')
            h2(text_ind(m)).BackgroundColor = tcd{3};    %if text has some background color switch to dark bkg theme
        end
    end
    
    % brighten patch colors if dim (use for the case of arrows etc)
    % this might not work well for all patch types so consider to comment
    for m=1:numel(patch_ind)
        h2(patch_ind(m)).FaceColor = adjust_color(h2(patch_ind(m)).FaceColor,tcd);
        h2(patch_ind(m)).EdgeColor = adjust_color(h2(patch_ind(m)).EdgeColor,tcd);
    end
    
    for m=1:numel(line_ind)
        h2(line_ind(m)).Color = adjust_color(h2(line_ind(m)).Color,tcd);
    end
    
    
    for m=1:numel(errorbar_ind)
        h2(errorbar_ind(m)).Color = adjust_color(h2(errorbar_ind(m)).Color,tcd);
        h2(errorbar_ind(m)).MarkerEdgeColor =   adjust_color(h2(errorbar_ind(m)).MarkerEdgeColor,tcd);
        h2(errorbar_ind(m)).MarkerFaceColor = adjust_color(h2(errorbar_ind(m)).MarkerFaceColor,tcd);
    end
    
    for m=1:numel(area_ind)
        h2(area_ind(m)).FaceColor = adjust_color(h2(area_ind(m)).FaceColor,tcd);
        h2(area_ind(m)).EdgeColor = adjust_color(h2(area_ind(m)).EdgeColor,tcd);
    end
    
    for m=1:numel(bar_ind)
        h2(bar_ind(m)).FaceColor = adjust_color(h2(bar_ind(m)).FaceColor,tcd);
        h2(bar_ind(m)).EdgeColor = adjust_color(h2(bar_ind(m)).EdgeColor,tcd);
    end


    for m=1:numel(hist_ind)
        h2(hist_ind(m)).FaceColor = adjust_color(h2(hist_ind(m)).FaceColor,tcd);
        h2(hist_ind(m)).EdgeColor = adjust_color(h2(hist_ind(m)).EdgeColor,tcd);
    end
    
    %       for m=1:numel(contour_ind)
    %         h2(contour_ind(m)).FaceColor = adjust_color(h2(contour_ind(m)).FaceColor,tcd);
    %         h2(contour_ind(m)).EdgeColor = adjust_color(h2(contour_ind(m)).EdgeColor,tcd);
    %     end
    
    
end
%% modify Colorbars:
for n=1:numel(colorbar_ind)
    colorbar_ind(n).Color        =  textcolor;
    colorbar_ind(n).Label.Color  =  textcolor;
end

%% modify Legends:

for n=1:numel(legend_ind)
    legend_ind(n).Color     = 'none';     % make white area transparent
    legend_ind(n).TextColor = textcolor;  % edit text color
    legend_ind(n).Box       = 'off';      % delete box
end


%% modify annotations:

ha=findall(gcf,'Tag','scribeOverlay');
% get its children handles
if ~isempty(ha)
    for n=1:numel(ha)
        hAnnotChildren = get(ha(n),'Children');
        try
            hAnnotChildrenType=get(hAnnotChildren,'type');
        catch
            disp('annotation not available')
            return
        end
        
        
        % edit lineType and shapeType colors
        textboxshape_ind        = find(strcmp(hAnnotChildrenType,'textboxshape'));
        ellipseshape_ind        = find(strcmp(hAnnotChildrenType,'ellipseshape'));
        rectangleshape_ind      = find(strcmp(hAnnotChildrenType,'rectangleshape'));
        textarrowshape_ind      = find(strcmp(hAnnotChildrenType,'textarrowshape'));
        doubleendarrowshape_ind = find(strcmp(hAnnotChildrenType,'doubleendarrowshape'));
        arrowshape_ind          = find(strcmp(hAnnotChildrenType,'arrowshape'));
        arrow_ind               = find(strcmp(hAnnotChildrenType,'Arrow')); % older Matlab ver
        lineshape_ind           = find(strcmp(hAnnotChildrenType,'lineshape'));
        
        
        for m=1:numel(textboxshape_ind)
            hAnnotChildren(textboxshape_ind(m)).Color      =  textcolor;
            hAnnotChildren(textboxshape_ind(m)).EdgeColor  =  adjust_color(hAnnotChildren(textboxshape_ind(m)).EdgeColor);
        end
        
        for m=1:numel(ellipseshape_ind)
            hAnnotChildren(ellipseshape_ind(m)).Color      =  adjust_color(hAnnotChildren(ellipseshape_ind(m)).Color,tcd);
            hAnnotChildren(ellipseshape_ind(m)).FaceColor  =  adjust_color(hAnnotChildren(ellipseshape_ind(m)).FaceColor,tcd);
        end
        
        for m=1:numel(rectangleshape_ind)
            hAnnotChildren(rectangleshape_ind(m)).Color      =  adjust_color(hAnnotChildren(rectangleshape_ind(m)).Color,tcd);
            hAnnotChildren(rectangleshape_ind(m)).FaceColor  =  adjust_color(hAnnotChildren(rectangleshape_ind(m)).FaceColor,tcd);
        end
        
        for m=1:numel(textarrowshape_ind)
            hAnnotChildren(textarrowshape_ind(m)).Color      =  adjust_color(hAnnotChildren(textarrowshape_ind(m)).Color,tcd);
            hAnnotChildren(textarrowshape_ind(m)).TextColor  =  textcolor;
            hAnnotChildren(textarrowshape_ind(m)).TextEdgeColor = adjust_color(hAnnotChildren(textarrowshape_ind(m)).TextEdgeColor,tcd);
        end
        
        for m=1:numel(doubleendarrowshape_ind)
            hAnnotChildren(doubleendarrowshape_ind(m)).Color = adjust_color(hAnnotChildren(doubleendarrowshape_ind(m)).Color,tcd);
        end
        
        for m=1:numel(arrowshape_ind)
            hAnnotChildren(arrowshape_ind(m)).Color = adjust_color(hAnnotChildren(arrowshape_ind(m)).Color,tcd);
        end
        
        for m=1:numel(arrow_ind)
            hAnnotChildren(arrow_ind(m)).Color = adjust_color(hAnnotChildren(arrow_ind(m)).Color,tcd);
        end
        
        for m=1:numel(lineshape_ind)
            hAnnotChildren(lineshape_ind(m)).Color = adjust_color(hAnnotChildren(lineshape_ind(m)).Color,tcd);
        end
        
        
    end
    
    
end

function  out=adjust_color(in,tcd)
% This function modifies an input color to fit a dark theme background.
% For that a color needs to have sufficient contrast (WCAG's AA standard of at least 4.5:1)
% The contrast ratio is calculate via :  cr = (L1 + 0.05) / (L2 + 0.05),
% where L1 is the relative luminance of the input color and L2 is the
% relative luminance of the dark mode background.
% For this case we will assume a dark mode theme background of...
% If a color is not passing this ratio, it will be modified to meet it
% via desaturation and brightness to be more legible.
% the function uses fminbnd, if you dont have the toolbox to use it you can
% replace it with fmintx (avaiable in Matlab's file exchange)

% if color is 'none' return as is
if strcmp(in,'none')
    out=in;
    return
end

if isa(in,'char') % for inputs such as 'flat' etc...
    out=in;
    return
end

dark_bkg_assumption=tcd{3};

% find the perceived lightness which is measured by some vision models
% such as CIELAB to approximate the human vision non-linear response curve.
% 1. linearize the RGB values (sRGB2Lin)
% 2. find Luminance (Y)
% 3. calc the perceived lightness (Lstar)
% Lstar is in the range 0 to 1 where 0.5 is the perceptual "middle gray".
% see https://en.wikipedia.org/wiki/SRGB ,

sRGB2Lin=@(in) (in./12.92).*(in<= 0.04045) +  ( ((in+0.055)./1.055).^2.4 ).*(in> 0.04045);
%Y = @(in) sum(sRGB2Lin(in).*[0.2126,  0.7152,  0.0722 ]);
Y = @(in) sum(bsxfun(@times,sRGB2Lin( in ),[0.2126,  0.7152,  0.0722 ]),2 );
Lstar = @(in)  0.01.*( (Y(in).*903.3).*(Y(in)<= 0.008856) + (Y(in).^(1/3).*116-16).*(Y(in)>0.008856));

Ybkg = sum(sRGB2Lin(dark_bkg_assumption).*[0.2126,  0.7152,  0.0722 ]);

cr = @(in)   (Y(in)' + 0.05) ./ (Ybkg + 0.05); % contrast ratio

% rgb following desaturation of factor x
ds=@(in,x) hsv2rgb( bsxfun(@times,rgb2hsv(in),[ones(numel(x),1) x(:) ones(numel(x),1)] ));

% rgb following brightness change of factor x
br=@(in,x) hsv2rgb( bsxfun(@power,rgb2hsv(in),[ones(numel(x),1) ones(numel(x),1) x(:)] ));


if cr(in)<tcd{2} % default is 4.5
    
    %check if color is just black and replace with perceptual "middle gray"
    if ~sum(in)
        fun0 = @(x) abs(Lstar( (ones(1,3)*x-dark_bkg_assumption ))-0.5);
        L_factor=fminbnd(fun0,0.3,1);
        
        out = ones(1,3)*L_factor;
        return
        
    end
    
    
    % if saturation is what reduce contrast then desaturate
    in_hsv=rgb2hsv(in);
    if in_hsv(2)>0.5
        
        fun1=@(x) abs(cr(ds(in,x))-tcd{2});
        [ds_factor, val]=fminbnd(fun1,0,in_hsv(2));
        
        if val<1e-2
            out = ds(in,ds_factor);
            return
        end
    end
    
    % desaturation alone didn't solve it, try to increase brightness
    fun2 =  @(x) abs(cr(br(in,x))-tcd{2});
    [br_factor, val]=fminbnd(fun2,0,1);
    
    if val<1e-2 && Lstar(br(in,br_factor))>0.5
        out = br(in,br_factor);
        return
    end
    
    % if niether worked then brightening + desaturation:
    fun3 = @(x) abs(cr(ds(br(in,br_factor),x))-tcd{2});
    [brds_factor, val]=fminbnd(fun3,0,1);
    
    if val<1e-2 && Lstar(ds(br(in,br_factor),brds_factor))>0.5
        out = ds(br(in,br_factor),brds_factor);
        return
        
    end
    
    % if all fails treat the color as black as above:
    fun0 = @(x) abs(Lstar( (ones(1,3)*x-dark_bkg_assumption ))-0.5);
    L_factor=fminbnd(fun0,0.3,1);
    out = ones(1,3)*L_factor;
    
else
    out = in ;
end

