function imOut = getChunkedData(IM, chunk, sz, varargin)

param = struct('numRows', 4, 'numCols', 4);
param = utility.parsenvpairs(param, [], varargin);

if nargin < 2; chunk = true; end

    if ~chunk
        d1 = sz(1); d2 = sz(2); d3 = sz(3);
    else
        [d1,d2,d3] = size(IM);
    end
    
    gridSize = [d1/param.numRows, d2/param.numCols, d3];
    gridSize = ceil(gridSize);
    
    [xx_s,xx_f,yy_s,yy_f,zz_s,zz_f,xx_us,xx_uf,yy_us,yy_uf,zz_us,zz_uf] = ...
            construct_grid(gridSize, [1,1,1] , d1,d2,d3, [32,32,16] );
    
    if chunk
        imOut = mat2cell_ov(IM,xx_s,xx_f,yy_s,yy_f,zz_s,zz_f, [1,1,0],[d1,d2,d3]);
    else %unchunk
        imOut = cell2mat_ov(IM,xx_us,xx_uf,yy_us,yy_uf,zz_us,zz_uf, [1,1,0], [d1,d2,d3]);
    end
end

function I = mat2cell_ov(X,xx_s,xx_f,yy_s,yy_f,zz_s,zz_f,overlap,sz)

% converts a matrix into a cell array with overlapping elements
% INPUTS:
% X:            Input matrix
% grid_size:    size of each element without overlap
% overlap:      amount of overlap
% sz:           spatial size of X

% OUTPUT:
% I:            output cell array

% Written by Eftychios A. Pnevmatikakis, Simons Foundation, 2016

I = cell(length(xx_s),length(yy_s),length(zz_s));
nd = length(sz);
if nd == 2; sz(3) = 1; end
for i = 1:length(xx_s)
    for j = 1:length(yy_s)
        for k = 1:length(zz_s)
            extended_grid = [max(xx_s(i)-overlap(1),1),min(xx_f(i)+overlap(1),sz(1)),max(yy_s(j)-overlap(2),1),min(yy_f(j)+overlap(2),sz(2)),max(zz_s(k)-overlap(3),1),min(zz_f(k)+overlap(3),sz(3))];
            if nd == 2
                I{i,j} = X(extended_grid(1):extended_grid(2),extended_grid(3):extended_grid(4),:);
            else
                I{i,j,k} = X(extended_grid(1):extended_grid(2),extended_grid(3):extended_grid(4),extended_grid(5):extended_grid(6),:);
            end
        end
    end
end
end

function X = cell2mat_ov(I,xx_s,xx_f,yy_s,yy_f,zz_s,zz_f,overlap,sz)

% converts a cell array to a matrix when the cell elements overlap
% INPUTS:
% I:            cell array
% grid_size:    true size of each element
% overlap:      amount of overlap in each direction
% d1:           number of rows of matrix
% d2:           number of columns of matrix

% OUTPUT:
% X:            output matrix

% Written by Eftychios A. Pnevmatikakis, Simons Foundation, 2016

X = NaN([sz,size(I{1,1},length(sz)+1)]);
if length(sz) == 2; sz(3) = 1; end

for i = 1:length(xx_f)
    for j = 1:length(yy_f)
        for k = 1:length(zz_f)
            extended_grid = [max(xx_s(i)-overlap(1),1),min(xx_f(i)+overlap(1),sz(1)),max(yy_s(j)-overlap(2),1),min(yy_f(j)+overlap(2),sz(2)),max(zz_s(k)-overlap(3),1),min(zz_f(k)+overlap(3),sz(3))];
            X(xx_s(i):xx_f(i),yy_s(j):yy_f(j),zz_s(k):zz_f(k)) = ...
                I{i,j,k}(1+(xx_s(i)-extended_grid(1)):end-(extended_grid(2)-xx_f(i)),1+(yy_s(j)-extended_grid(3)):end-(extended_grid(4)-yy_f(j)),1+(zz_s(k)-extended_grid(5)):end-(extended_grid(6)-zz_f(k)));
        end
    end
end
end

function [xx_s,xx_f,yy_s,yy_f,zz_s,zz_f,xx_us,xx_uf,yy_us,yy_uf,zz_us,zz_uf] = construct_grid(grid_size,mot_uf,d1,d2,d3,min_patch_size)

xx_s = 1:grid_size(1):d1;
yy_s = 1:grid_size(2):d2;
zz_s = 1:grid_size(3):d3;

xx_f = [xx_s(2:end)-1,d1];
yy_f = [yy_s(2:end)-1,d2];
zz_f = [zz_s(2:end)-1,d3];

if xx_f(end)-xx_s(end) + 1 < min_patch_size(1) && length(xx_s) > 1; xx_s(end) = []; xx_f(end-1) = []; end
if yy_f(end)-yy_s(end) + 1 < min_patch_size(2) && length(yy_s) > 1; yy_s(end) = []; yy_f(end-1) = []; end
if zz_f(end)-zz_s(end) + 1 < min_patch_size(3) && length(zz_s) > 1; zz_s(end) = []; zz_f(end-1) = []; end

grid_size_us = floor(grid_size./mot_uf);
if mot_uf(1) > 1
    xx_us = 1:grid_size_us(1):d1;
    xx_uf = [xx_us(2:end)-1,d1];
else
    xx_us = xx_s; xx_uf = xx_f;
end
if mot_uf(2) > 1
    yy_us = 1:grid_size_us(2):d2;
    yy_uf = [yy_us(2:end)-1,d2];
else
    yy_us = yy_s; yy_uf = yy_f;
end
if mot_uf(3) > 1
    zz_us = 1:grid_size_us(3):d3;
    zz_uf = [zz_us(2:end)-1,d3];
else
    zz_us = zz_s; zz_uf = zz_f;
end
end
