function IM = okada(IM)

numFrames = size(IM, 3);

IM = cat(3, IM(:, :, 2), IM, IM(:, :, end-2));

for i = 2:numFrames
    
    prevImage = IM(:, :, i-1);
    thisImage = IM(:, :, i);
    nextImage = IM(:, :, i+1);
    
%    TF = (thisImage-prevImage) .* (thisImage-nextImage) > 0;
    diffPrev = thisImage-prevImage;
    diffNext = thisImage-nextImage;
    TF = sign(diffPrev) == sign(diffNext);

    thisImage(TF) = (prevImage(TF) + nextImage(TF)) ./ 2;
    
    IM(:, :, i) = thisImage;
    
end
IM = IM(:, :, 2:end-1);


end