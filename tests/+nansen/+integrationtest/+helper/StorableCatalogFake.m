classdef StorableCatalogFake < utility.data.StorableCatalog
%StorableCatalogFake Minimal concrete catalog for exercising file io
%
%   A working but deliberately simple StorableCatalog subclass. It exists
%   so tests can drive the persistence logic of the superclass without
%   depending on a real model such as DataLocationModel, whose
%   construction reaches into the current project.
%
%   See also utility.data.StorableCatalog

    properties (Constant, Hidden)
        ITEM_TYPE = 'TestItem'
    end

    methods
        function obj = StorableCatalogFake(varargin)
            obj@utility.data.StorableCatalog(varargin{:})
        end
    end

    methods (Static)

        function S = getBlankItem()
        %getBlankItem Return an unpopulated item
        %
        %   Name must come first so that the superclass can derive item
        %   names from the leading field.
            S = struct('Name', '', 'Value', 0);
        end

        function S = getDefaultItem()
        %getDefaultItem Return an item with default values
            S = nansen.integrationtest.helper.StorableCatalogFake.getBlankItem();
            S.Name = 'DefaultItem';
        end

        function pathStr = getDefaultFilePath() %#ok<STOUT>
        %getDefaultFilePath Not supported; tests must pass a path
            error('StorableCatalogFake:NoDefaultFilePath', ...
                'This catalog has no default location. Construct it with an explicit file path.')
        end
    end
end
