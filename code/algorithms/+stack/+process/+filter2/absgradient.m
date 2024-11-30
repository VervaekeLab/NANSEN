function imOut = absgradient(im)

    if ndims(im)==3
        im = mean(im, 3);
    end
    
    grIm = abs(gradient(single(im)));
    %grIm = padarray(grIm,[1,1],0,'pre');

    %imOut = stack.makeuint8(grIm);
    
    imOut = imadjustn(grIm);
    imOut = im2uint8(imOut);

    imOut = double(imOut);
end
