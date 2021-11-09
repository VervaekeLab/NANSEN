classdef FileAdapter % superclass

    properties (Abstract, Constant, Hidden)
        SUPPORTED_EXTENSIONS
    end

    properties
        FilePath
        MetaData
        Data
    end

    methods 
        open(obj)
        view(obj)
        load(obj)
        save(obj)
    end

end