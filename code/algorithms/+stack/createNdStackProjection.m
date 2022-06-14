function imArrayOut = createNdStackProjection(imArrayIn, method, dim, varargin)

    if ischar(method); method = str2func(method); end
    
    if ndims(imArrayIn) > 4
        error('Not implemented for stacks with more than 4 dimensions') % Todo
    end
    
    % Rearrange the dimensions to get the primary dimensions on the 3rd
    % dimension.
    dimOrderTmp = 1:ndims(imArrayIn);
    dimOrderTmp = [dimOrderTmp(1:2), dim, setdiff(dimOrderTmp(3:end), dim, 'stable')];
    
    imArrayIn = permute(imArrayIn, dimOrderTmp);
    arraySize = size(imArrayIn);

    imArrayOut = zeros(imageHeight, imageWidth, arraySize(4:end));
        
    for i = 1:size(imArrayIn, 4)
        imArrayOut(:,:,i) = method(imArrayIn(:,:,:,i), 3, varargin{:});
    end
    imArrayOut = cast(imArrayOut, class(imArray));
    
end