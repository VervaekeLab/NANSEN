function cIm = globalCorrelation(IM, dim)
% createCorrelationProjection
%
%   cIm = createCorrelationProjection(IM)
%
% This projection shows how much each pixel correlated with the average of
% all pixel values.

% Todo: Make chunking dependent on input and or available memory.


if ndims(IM) > 3
    error('Not implemented for matrices with more than 3 dims'); 
end

P = double( prctile(single(IM(:)), [0.5, 99.5]) );


% Calculate the average signal of all pixels per time point
imageSignal = mean(mean(IM,2),1);
imageSignal = single( squeeze(imageSignal) );


% Divide data into chunks to use less memory during calculation
tmpIm = stack.reshape.imsplit(IM, true, [], 'numRows', 16, 'numCols', 16);
tmpC = cell(size(tmpIm));


for i = 1:size(tmpIm,1)
    for j = 1:size(tmpIm,2)
        
        [d1,d2,d3] = size(tmpIm{i,j});
        pixelSignals = transpose( reshape( tmpIm{i,j} , d1*d2, d3) );
        pixelSignals = single(pixelSignals);
        

        % Calculate the correlation of each pixel with the image signal.
        % Note: data is cast to single and transposed to row vectors.
        RHO = corr(imageSignal, pixelSignals, 'tail', 'right', 'rows', 'all');
        rhoIm = reshape(RHO, d1,d2);
        
        tmpC{i, j} = rhoIm;
    end
end

% Unchunk data
[d1,d2,~] = size(IM);
cIm = stack.reshape.imsplit(tmpC, false, [d1,d2,1], 'numRows', 16, 'numCols', 16);

% todo: cast...
cIm = cIm .* range(P) + P(1);
cIm = cast(cIm, class(IM));

%cIm = stack.makeuint8(cIm);

end