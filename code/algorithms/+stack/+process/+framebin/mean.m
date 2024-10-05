function Y = mean(Y, dsFactor)
%tempbin.mean Temporal downsampling of stack by mean

if nargin < 2; dsFactor = 10; end

% Create moving average stack
nDs = floor(size(Y, 3) / dsFactor);

[imHeight, imWidth, ~] = size(Y);
Y = reshape(Y(:,:,1:nDs*dsFactor), imHeight, imWidth, dsFactor, nDs);
Y = squeeze(mean(Y, 3));

end
