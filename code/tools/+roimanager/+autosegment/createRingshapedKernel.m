function kernel = createRingshapedKernel(im, varargin)


def = struct('InnerRadius', 4, 'OuterRadius', 6, 'BoxSize', [21,21]);
opt = utility.parsenvpairs(def, [], varargin);


imOrig = im;

nuc = prctile(imOrig(:), 5);
bg = prctile(imOrig(:), 50);
fg = prctile(imOrig(:), 99);

se1 = strel('rect', opt.BoxSize);
se2 = strel('disk', opt.InnerRadius);
se3 = strel('disk', opt.OuterRadius);

m1 = se1.Neighborhood;
m2 = stack.reshape.imexpand(se2.Neighborhood, size(se1.Neighborhood));
m3 = stack.reshape.imexpand(se3.Neighborhood, size(se1.Neighborhood));

m1 = m1 & ~m3; 
m3 = m3 & ~m2;

m1 = single(m1); m2 = single(m2); m3 = single(m3);

m1(m1==1)=bg;
m2(m2==1)=nuc;
m3(m3==1)=fg;

kernel = m1+m2+m3;
kernel = single(kernel);

kernel = stack.process.filter2.gauss2d(single(kernel), 1);

end