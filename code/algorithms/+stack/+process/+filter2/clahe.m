function varargout = clahe(imageIn, varargin)

    param = struct();
    param.NumTiles = [32, 32];
    param.ClipLimit = 0.015;
    param.ClipLimit_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 0.1, 'nTicks', 101}});
    param.Range = 'original';
    param.Range_ = {'full', 'original'};
    param.Distribution = 'rayleigh';
    param.Distribution_ = {'uniform', 'rayleigh', 'exponential'};
    
    if nargin == 0
        varargout = {param}; return
    end
    
    param = utility.parsenvpairs(param, [], varargin);
    
    imclass = class(imageIn);
    imageIn = double(imageIn);
    
    minVal = min(imageIn(:));
    maxVal = max(imageIn(:));
    
    imageIn = (imageIn - minVal) ./ (maxVal - minVal);
    
    if size(imageIn,1) < 32 ||  size(imageIn,2) < 32
        im = imageIn;
    else
        numFrames = size(imageIn, 3);
        im = zeros(size(imageIn));
        
        for i = 1:numFrames
            im(:, :, i) = adapthisteq(imageIn(:, :, i), 'NumTiles', param.NumTiles, ...
                            'ClipLimit', param.ClipLimit, ...
                            'Distribution', param.Distribution, ...
                            'Range', param.Range);
        end
                    
        % Should I use range = full instead???
        im = im .* (maxVal-minVal) + minVal;
        im = cast(im, imclass);
    end

    varargout = {im};

end

% Old implementation. Todo: Does above work well for single,double etc?

% % % switch obj.imClass
% % %     case  {'uint8', 'uint16'}
% % %
% % %         meanProjection = mean(imdata, 3);
% % %         origRange = range(meanProjection(:));
% % %
% % %         normalize = @(im) (im-min(im(:))) ./ range(im(:));
% % %         meanProjection = normalize(meanProjection);
% % %
% % %         % Do imadjust to make surefull bitdepth is used...
% % %         switch obj.imClass
% % %             case 'uint8'
% % %                 meanProjection = uint8(meanProjection.*(2^8-1));
% % %             case 'uint16'
% % %                 meanProjection = uint16(meanProjection.*(2^16-1));
% % %         end
% % %
% % %         im = imadjust(meanProjection);
% % %
% % %         obj.imObj.CData = adapthisteq(im, ...
% % %                 'NumTiles', [32, 32], ...
% % %                 'ClipLimit', 0.015, ...
% % %                 'Distribution', 'rayleigh');
% % %
% % %         im = normalize( single(im) ) .* origRange;
% % %         im = cast(im, obj.imClass);
% % %
% % %         obj.imObj.CData = im;
% % %
% % %     case {'double', 'single'}
% % %
% % %         tmpim = mean(imdata, 3);
% % %         minVal = min(tmpim(:));
% % %         maxVal = max(tmpim(:));
% % %         tmpim = (tmpim-minVal) ./ (maxVal-minVal);
% % %
% % %         result = adapthisteq(tmpim, ...
% % %                 'NumTiles', [32, 32], ...
% % %                 'ClipLimit', 0.015, ...
% % %                 'Distribution', 'rayleigh', ...
% % %                 'Range', 'original');
% % %
% % %         obj.imObj.CData = result .* (maxVal-minVal) + minVal;
% % %
% % %     otherwise
% % %         obj.imObj.CData = [];
% % % end
