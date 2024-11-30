function roiArray = run(imArray, ops)

% Todo:
%   1. Is there a difference between nSVDforROI and nSVD

% Use hijacked fprintf if available
global fprintf
if isempty(fprintf); fprintf = str2func('fprintf'); end

imArray = imArray - mean(imArray,3);

% Get the default options for autosegmentation
ops.splitROIs = getOr(ops, {'splitROIs'}, 1);
ops.diameter = getOr(ops, 'diameter', 10);
ops.clustrules.diameter = ops.diameter;
ops.clustrules = get_clustrules(ops.clustrules);
ops.ThScaling   = getOr(ops, 'ThScaling', 1);
% ops.maxIterRoiDetection = 5;

model = struct;

% Find the svd components  % [ops, U0, model, U2] = get_svdForROI(ops);

U = []; Sv = []; V = []; Fs = []; sdmov = [];

% Find image size
[Ly, Lx, nFrames] = size(imArray);
ops.yrange = 1:Ly;
ops.xrange = 1:Lx;

% number of frames to use for SVD
ops.NavgFramesSVD = min(ops.NavgFramesSVD, nFrames);

% Number of images to do svd on...
ops.nSVDforROI = min(ops.nSVDforROI, size(imArray,3));
 
% smooth spatially to get high SNR SVD components
imArraySmooth = zeros(size(imArray), 'like', imArray);
if ops.sig>0.05
    for i = 1:size(imArray,3)
        I = imArray(:,:,i);
        I = my_conv2(I, ops.sig, [1 2]);
        imArraySmooth(:,:,i) = I;
    end
end
    
imArraySmooth = reshape(imArraySmooth, [], size(imArraySmooth,3));

% compute noise variance across frames (assumes slow signal)
if 1
    sdmov = mean(diff(imArraySmooth, 1, 2).^2, 2).^.5;
else
    sdmov = mean(mov.^2,2).^.5;
end

sdmov           = reshape(sdmov, Ly, Lx);
sdmov           = max(1e-10, sdmov);
ops.sdmov       = sdmov;

% smooth the variance over space
    
% normalize pixels by noise variance
imArraySmooth = bsxfun(@rdivide, double(imArraySmooth), sdmov(:));
model.sdmov = sdmov;
    
% compute covariance of frames
COV = imArraySmooth' * imArraySmooth/size(imArraySmooth,1);

ops.nSVDforROI = min(size(COV,1)-2, ops.nSVDforROI);
    
% compute SVD of covariance matrix
[V, Sv] = eigs(double(COV), ops.nSVDforROI);
Sv = single(diag(Sv));
    
U = single( imArraySmooth * V );

% reshape U to frame size
U = reshape(U, Ly, Lx, []);
    
% compute spatial masks (U = mov * V)
% imArray = loadAndBin(ops, Ly, Lx, nimgbatch, nt0);
imArray = reshape(imArray, [], size(imArray,3));
    
% U2 = imArray * V;
% U2 = single(U2);
%
% % reshape U to frame size
% U2 = reshape(U2, Ly, Lx, []);

% % project spatial masks onto raw data
% fid = fopen(ops.RegFile, 'r');
% ix = 0;
%
% Fs = zeros(ops.nSVDforROI, sum(ops.Nframes), 'single');
%
% while 1
%     data = fread(fid,  Ly*Lx*nimgbatch, '*int16');
%     if isempty(data)
%         break;
%     end
%     data = single(data);
%     data = reshape(data, Ly, Lx, []);
%
%     % subtract off the mean of this batch
%     data = bsxfun(@minus, data, mean(data,3));
%     %     data = bsxfun(@minus, data, ops.mimg1);
%     data = data(ops.yrange, ops.xrange, :);
%
%     Fs(:, ix + (1:size(data,3))) = U' * reshape(data, [], size(data,3));
%
%     ix = ix + size(data,3);
% end
% fclose(fid);
%
% save(sprintf('%s/SVDroi_%s_%s_plane%d.mat', ops.ResultsSavePath, ...
%     ops.mouse_name, ops.date, ops.iplane), 'U', 'Sv', 'Fs', 'ops');

% reshape U to be (nMaps x Y x X)
U =  reshape(U, [], size(U,ndims(U)))';

[nSVD, Npix] = size(U);
U = reshape(U, nSVD, Ly, Lx);

% compute neuropil basis functions for cell detection
S = getNeuropilBasis(ops, Ly, Lx, 'Fourier'); % 'raisedcosyne', 'Fourier'
S = normc(S);
nBasis = size(S,2);

StU = S'*U(:,:)'; % covariance of neuropil with spatial masks
StS = S'*S; % covariance of neuropil basis functions

% make cell mask with ops.diameter
d0   = ceil(ops.diameter); % expected cell diameter in pixels
sig = ceil(d0/4);
dx = repmat([-d0:d0], 2*d0+1, 1);
dy = dx';
rs = dx.^2 + dy.^2 - d0^2;
dx = dx(rs<=0);
dy = dy(rs<=0);

% initialize cell matrices
mPix    = zeros(numel(dx), 1e4);
mLam    = zeros(numel(dx), 1e4);

iter = 0;
icell = 0;
r = rand(1e4,1);

L   = sparse(Ly*Lx, 0);
LtU = zeros(0, nSVD);
LtS = zeros(0, nBasis);

% regress maps onto basis functions and subtract neuropil contribution
% U = Ucell + neu'*S'
% neu = inv(S'*S) * (S'*U')
neu     = StS\StU;
Ucell   =  U - reshape(neu' * S', size(U));

nBasis = size(S,2);

%
while 1
    iter = iter + 1;
    
    % residual is smoothed at every iteration
    us = my_conv2_circ(Ucell, sig, [2 3]);

    % compute log variance at each location
    V = sq(mean(us.^2,1));
    V = double(V);
    
    um = sq(mean(Ucell.^2,1));
    um = my_conv2_circ(um, sig, [1 2]);
    
    V = V./um ;
    %     V = log(V./um);
    V = double(V);
    % do the morphological opening trick
    % take the running max of the running min
    % this normalizes the brightness of the image
    if iter==1
        lbound = -my_min2(-my_min2(V, d0), d0);
    end
    
    V = V - lbound;
    
    if iter==1
        % find indices of all maxima  in plus minus 1 range
        % use the median of these peaks to decide stopping criterion
        maxV    = -my_min(-V, 1, [1 2]);
        ix      = (V > maxV-1e-10);
        
        % threshold is the mean peak, times a potential scaling factor
        pks = V(ix);

        Th  = ops.ThScaling * median(pks(pks>1e-4));
        
        ops.Vcorr = V;
    end
    
    % just in case this goes above original value
    V = min(V, ops.Vcorr);
    
    % find local maxima in a +- d neighborhood
    maxV = -my_min(-V, d0, [1 2]);
    
    % find indices of these maxima above a threshold
    ix  = (V > maxV-1e-10) & (V > Th);
    ind = find(ix);
    
    if iter==1
       Nfirst = numel(ind);
    end
    
    if numel(ind)==0
        break;
    end
    
    new_codes = normc(us(:, ind));
    
    ncells = icell;
    LtU(ncells+size(new_codes,2), nSVD) = 0;
    
    % each source needs to be iteratively subtracted off
    for i = 1:size(new_codes,2)
        icell = icell + 1;
        [ipix, ipos] = getIpix(ind(i), dx, dy, Lx, Ly);
        
        Usub = Ucell(:, ipix);
        
        lam = max(0, new_codes(:, i)' * Usub);
        
        % threshold pixels
        lam(lam<max(lam)/5) = 0;
                 
        mPix(ipos,icell) = ipix;
        mLam(ipos,icell) = lam;
        
        % extract biggest connected region of lam only
        mLam(:,icell)   = normc(getConnected(mLam(:,icell), rs)); % ADD normc HERE and BELOW!!!
        lam             = mLam(ipos,icell) ;
        
        L(ipix,icell)   = lam;
        
        LtU(icell, :)   = U(:,ipix) * lam;
        LtS(icell, :)   = lam' * S(ipix,:);
    end
    
    % ADD NEUROPIL INTO REGRESSION HERE
    LtL     = full(L'*L);
    codes   = ([LtL LtS; LtS' StS]+ 1e-3 * eye(icell+nBasis))\[LtU; StU];
    neu     = codes(icell+1:end,:);
    codes   = codes(1:icell,:);
%     codes = (LtL+ 1e-3 * eye(icell))\LtU;
    
    % subtract off everything
    Ucell = U - reshape(neu' * S', size(U)) - reshape(double(codes') * L', size(U));
    
    % re-estimate masks
    L   = sparse(Ly*Lx, icell);
    for j = 1:icell
        ipos = find(mPix(:,j)>0);
        ipix = mPix(ipos,j);
        
        Usub = Ucell(:, ipix)+ codes(j, :)' * mLam(ipos,j)';
        
        lam = max(0, codes(j, :) * Usub);
        % threshold pixels
        lam(lam<max(lam)/5) = 0;
        
        mLam(ipos,j) = lam;

        % extract biggest connected region of lam only
        mLam(:,j) = normc(getConnected(mLam(:,j), rs));
        lam = mLam(ipos,j);
        
        L(ipix,j) = lam;
        
        LtU(j, :) = U(:,ipix) * lam;
        LtS(j, :) = lam' * S(ipix,:);
        
        Ucell(:, ipix) = Usub - (Usub * lam)* lam';
    end
    %
    err(iter) = mean(Ucell(:).^2);
    
    Vnew = sq(sum(Ucell.^2,1));
    
    fprintf('%d total ROIs, err %4.4f, thresh %4.4f \n', icell, err(iter), Th)
   
     if (numel(ind)<Nfirst * getOr(ops, 'stopSourcery', 1/10)) || (iter>= getOr(ops, 'maxIterRoiDetection', 100))
        break;
    end
end

% this runs only the mask re-estimation step, on non-smoothed PCs
% (because smoothing is done during clustering to help)
% if getOr(ops, 'refine', 1)
% 	sourceryAddon;
% else
% 	fprintf('no refinement of ROIs done\n')
% end

mLam  =  mLam(:, 1:icell);
mPix  =  mPix(:, 1:icell);

mLam = bsxfun(@rdivide, mLam, sum(mLam,1));
%%

% subtract off neuropil only
Ucell = U - reshape(neu' * S', size(U));

% populate stat with cell locations and footprint
stat = getFootprint(ops, codes, Ucell, mPix, mLam);
roiArray = nansen.twophoton.autosegmentation.suite2p.getRoiArray(stat, [Ly, Lx]);

% % compute compactness of ROIs
% stat = anatomize(ops, mPix, mLam, stat);
%
% [~, iclust, lam] = drawClusters(ops, r, mPix, mLam, Ly, Lx);
%
% model.L     = L;
% model.S     = S;
% model.LtS   = LtS;
% model.LtL   = LtL;
% model.StS   = StS;
%
% % get anatomical projection weights
% stat = weightsMeanImage(ops, stat, model);

end
