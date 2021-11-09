function imOut = gradient(imArray)    

    if ndims(imArray)==3
        im = mean(imArray, 3);
    end
    grIm = gradient(single(im));
    grIm = padarray(grIm,[1,1],0,'pre');

    imOut = stack.makeuint8(grIm);
    
end