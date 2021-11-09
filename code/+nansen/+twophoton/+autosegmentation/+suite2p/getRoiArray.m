function roiArray = getRoiArray(stat, imsize)

roiArray = RoI.empty;

for i = 1:numel(stat)
    
   mask = false(imsize);
   mask(stat(i).ipix)=true;
   roiArray(i) = RoI('Mask', mask, imsize);
    
end

end