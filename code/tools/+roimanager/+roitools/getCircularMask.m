function mask = getCircularMask(imSize, x, y, r)

    [xx, yy] = meshgrid((1:imSize(2)) - x, (1:imSize(1)) - y);
    mask = (xx.^2 + yy.^2) < r^2 ;

end