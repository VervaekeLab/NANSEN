function hImageStack = ImageStack(datareference, varargin)
%IMAGESTACK Create an ImageStack object
%
%   imageStack = ImageStack(data) returns an ImageStack object 
%       based on the data variable. The data variable must be an 
%       array with 2-5 dimensions.
%
%   imageStack = ImageStack(virtualData) returns an ImageStack object 
%       based on the image data represented by the virtualData object. 
%
%   imageStack = ImageStack(filePath) returns an ImageStack object 
%       based on the data in the file referenced by filePath. The file 
%       must be compatible with a virtualArray adapter. Some common file 
%       formats like tiff, h5 and binary files have basic support. 
%       See nansen/datatypes/+nansen/+stack/+virtual for all available 
%       virtualArray adapters.
%
%   imageStack = ImageStack(..., Name, Value) creates the ImageStack 
%       object and specifies values of properties on construction.


    if ~nargin
        hImageStack = nansen.stack.ImageStack();
    else
        hImageStack = nansen.stack.ImageStack(datareference, varargin{:});
    end

end
