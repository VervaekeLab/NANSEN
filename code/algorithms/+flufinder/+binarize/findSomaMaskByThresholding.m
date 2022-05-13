function [roiMask, stats] = findSomaMaskByThresholding(im, varargin)
%findSomaMaskByThresholding Find mask for an image of a neuronal soma
%
%   This function detects the threshold level for a soma with a darker
%   nucleus, then binarizes the image, and finally processes the mask to
%   fill nucleus and smaller holes and also remove small objects.
%
%   roiMask = findSomaMaskByThresholding(im, varargin)
%
%   INPUTS: 
%       im : thumbnail (cropped) image of a neuronal soma
%      
%   OPTIONS : 
%       InnerDiameter : Expected diameter of nucleus
%       OuterDiameter : Expected diameter of cell body
    
% Todo: Extended roi radius. See roiEditor

    def = struct('InnerDiameter', 6, 'OuterDiameter', 11, 'ShowResults', false);
    opt = utility.parsenvpairs(def, [], varargin);
    
    d1 = opt.InnerDiameter; d2 = opt.OuterDiameter;

    % Store the original version of the image.
    imOrig = im;
    
    % Ignore zero values
    im = double(im);
    im(im==0) = nan;
    
    % Define center coordinates and radius
    imSize = size(im);
    center = imSize / 2;
    
    r1 = d1/2;
    r2 = d2/2;
    minRoiArea = round(pi*(r2^2)/2);

    % Generate grid with coordinates centered on image center
    [yy, xx] = ndgrid((1:imSize(1)) - center(1), (1:imSize(2)) - center(2));
    
    mask1 = (xx.^2 + yy.^2) < r1^2; % Nucleus of soma
    mask2 = (xx.^2 + yy.^2) < r2^2; % Nucleus + cytosol
    mask3 = logical(mask2 - mask1); % Cytosol excluding nucleus

    nucleusValues = im(mask1);
    somaValues = im(mask2);
    cytosolValues = im(mask3);
    surroundValues = im(~mask2);

    if ~isempty(nucleusValues)
        %  nucleus_val = median(nucleus_values);
        mediCytosolValue = nanmedian(cytosolValues);
        mediSurroundValue = nanmedian(surroundValues(1:round(end*0.6)));
        T = mediSurroundValue + (mediCytosolValue - mediSurroundValue) / 2;
    else 
        high_val = nanmedian(somaValues);
        low_val = nanmedian(surroundValues);
        
        T = low_val + (high_val - low_val) / 2;
    end
    
    im = medfilt2(im, [5, 5]);

    % Create roimask
    roiMask = imbinarize(im, double(T));
    if ~isempty(nucleusValues)
        roiMask(mask1) = 1;
    end
    
    % Remove small "holes"
    roiMask = bwareaopen(roiMask, minRoiArea);
    roiMask = imfill(roiMask, 'holes');

    if opt.showResults
        plotResults(imOrig, im, roiMask)
    end
    
    if nargout == 2
        stats = createStats(im, roiMask);
    end
    
end

function stats = createStats(im, roiMask)
%createStats Create stats based on detected roimask
    stats = struct;
    
    roiBrightness = nanmedian(nanmedian( im(roiMask) ));
    pilBrightness = nanmedian(nanmedian( im(~roiMask) ));
    
    stats.dff = (roiBrightness-pilBrightness+1) ./ (pilBrightness+1);
    stats.val = roiBrightness;
end

function plotResults(imOrig, im, mask)
%plotResults Plot the results of binarization

    persistent f ax1 ax2
    if isempty(f) || ~isvalid(f)
        f = figure('Position', [300,300,600,300], 'MenuBar', 'none'); 
        ax1 = axes(f, 'Position',[0,0,0.5,1]);
        ax2 = axes(f, 'Position',[0.5,0,0.5,1]);

    else
        cla(ax1)
        cla(ax2)
    end

    h1 = imagesc(ax1, im); hold on
    h1.AlphaData = 1-mask.*0.5;axis(ax1, 'image')
    
    h2 = imagesc(ax2, imOrig); hold on
    h2.AlphaData = 1-mask.*0.5;axis(ax2, 'image')
    ax1.YDir = 'reverse';
    ax2.YDir = 'reverse';
    
end