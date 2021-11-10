function im = openimg(filePath)
    
    im = [];
    
    if ~nargin || isempty(filepath)

        [fileName, filePath] = uigetfile({ '*.tif;*.tiff;*.png;*.jpg;*.jpeg;*.JPG', ...
                                            'Image Files (*.tif, *.tiff, *.png, *.jpg, *.jpeg, *.JPG)'; ...
                                           '*', 'All Files (*.*)'}, 'Select Image File');
        filePath = fullfile(filePath, fileName);
        if fileName == 0; return; end % User pressed cancel

    end
    
    im = imread(filePath);

end