function imArray = preprocessImages(imArray, varargin)
     
    imArray = single(imArray);

    % Create a temporally downsampled stack (binned by maximum)
    imArray = stack.process.framebin.max(imArray, 5);
    
    % Preprocess (subtract dynamic background)
    %optsNames = {'FilterSize'};
    %opts = utility.struct.substruct(params, optsNames);
    opts = {'FilterSize', 20};
    imArray = flufinder.preprocess.removeBackground(imArray, opts{:});
    
    % Preprocess (subtract static background)
    opts = {'Percentile', 25};
    imArray = flufinder.preprocess.removeStaticBackground(imArray, opts{:});

end