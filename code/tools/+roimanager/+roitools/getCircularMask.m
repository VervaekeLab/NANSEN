function mask = getCircularMask(imSize, x, y, r)
    
    [xx, yy] = meshgrid((1:imSize(2)) - x, (1:imSize(1)) - y);
    mask = (xx.^2 + yy.^2) < r^2 ;

    return
    
% % %     % More efficient way if image are high res
% % %     BW = false(imSize);
% % %
% % %     [xx, yy] = meshgrid((-r:r) - mod(x,1), (-r:r) - mod(y,1));
% % %     mask = (xx.^2 + yy.^2) < r^2 ;
% % %     [X, Y] = find(mask);
% % %     x0 = mean(X); y0 = mean(Y); % Find center
% % %
% % %     X = round(X + x - x0 - 1); % Subtract 1 to account for pixel indices starting at 1??
% % %     Y = round(Y + y - y0 - 1);
% % %     ind = sub2ind(imSize, Y, X);
% % %
% % %     BW(ind) = true;
% % %     mask = BW;

end
