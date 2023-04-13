classdef DataLocationRoot < handle
%DataLocationRoot Specification for a datalocation root directory

    properties
        Key char
        Value char
    end

    properties (SetAccess = private)
        StorageType % Todo: make enum
        DeviceName char
    end

    

end