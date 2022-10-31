function unrolledIm = imunroll(IM)

%
%                 o                                                            
%           `Lt1zzQzz11t;                       ZXlllllllllllllllllllllllXZ   
%         1ox,    N    `=ja~                    Z|           ^           |Z   
%       \p~       N        tK'                  Z|           z           |Z   
%      H)     A-> N <-B     `B;                 Z|                       |Z   
%     4\          N           @`                Z|                       |Z   
%     @           N           rp                Z|                       |Z   
%    'Q                        @                Z|<-A                 B->|Z   
%     @           ^           ;%                Z|                       |Z   
%     D^          z           Q'                Z|                       |Z   
%      B^                    R*                 Z|                       |Z   
%       oP`                +D~                  Z|                       |Z   
%        -oo*           ,FZ|                    Z|           o           |Z   
%           ;st1zzlzz11s\`                      ZXlllllllllllllllllllllllXZ   
%                ooo                                                                 
                                                                                


% Get size of input image array
[imHeight, imWidth, nFrames] = size(IM);

% Calculate center of image
imCenter = [(imHeight+1)/2, (imWidth+1)/2];

% Create cartesian coordinate system centered on the image center
[xx, yy] = meshgrid( (1:imWidth)-imCenter(2), (1:imHeight)-imCenter(1) );
yy = flipud(yy); % Reverse y-axis from array indices to coordinates.

% Get corresponding polar coordinates for each pixel of the image.
[theta, rho] = cart2pol(xx, yy);

% Find the radius of the shortest dimension
rad = round(min([max(xx(:)), max(yy(:))]));

% Convert theta from radians (+/- pi) to degrees from 0 to 360
theta = rad2deg(theta);
theta(theta<0) = 180 + (180 - abs(theta(theta<0)));

% Round off the radius to integers
rho = round(rho);

% Preallocate array for the indices conversion when "unfolding" the image
IND = cell(rad, 1);

% Unroll
% Starting from the center, and going counterclockwise, assign each pixel
% to a new index. The index should be the position in an "unrolled" image
for r = 1:rad
    rhoIND = find(rho==r);
    [~, order] = sort(theta(rhoIND));
    rhoIND = rhoIND(order);
    IND{r} = rhoIND;
end

% Calculate the number of pixels
pixPerImage = imHeight*imWidth;

% Allocate the array for the unfolded image
unrolledIm = zeros([rad, imWidth, nFrames], 'like', IM);
 
% Divide the image into concentric circles where each circle
% is one row in the new image. Each column is one angle.
% Pixels on the top row will be very stretched out, and pixels on the
% bottom will be squeezed.
for j = 1:rad
    % Repeat the indices for the current radius across all images
    tmpInd = repmat( IND{j}', nFrames, 1 ) + (0:(nFrames-1))'*pixPerImage;
    
    tmpInd = tmpInd';
    imLin = IM(tmpInd(:));
    imLin = reshape(imLin, [], nFrames);
    imLin = imresize(imLin, [imWidth, nFrames]);
    unrolledIm(j, :, :) = imLin;

end


end