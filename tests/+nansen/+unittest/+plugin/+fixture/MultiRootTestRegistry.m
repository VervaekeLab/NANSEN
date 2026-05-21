classdef MultiRootTestRegistry < nansen.plugin.base.Registry
%MultiRootTestRegistry Test fixture: registry with an ordered list of root paths.
%
%   Used to test precedence, shadowing, and duplicate-Id handling across
%   multiple discovery roots. Must not be used in production code.

    properties (Constant, Access = protected)
        PluginType      = nansen.plugin.enum.PluginType.FileAdapter
        SidecarFilename = "test.plugin.json"
    end

    properties
        RootPaths (1,:) cell = {}
    end

    methods

        function obj = MultiRootTestRegistry(rootPaths, projectFolder)
        %MultiRootTestRegistry Construct with an ordered cell array of root paths.
            arguments
                rootPaths = {}
                projectFolder (1,1) string = ""
            end
            obj@nansen.plugin.base.Registry(projectFolder)
            if ischar(rootPaths) || isstring(rootPaths)
                rootPaths = cellstr(rootPaths);
            end
            obj.RootPaths = rootPaths;
        end

    end

    methods (Access = protected)

        function roots = getRootPaths(obj)
            roots = obj.RootPaths;
        end

        function specs = discoverCompatibilitySpecs(~)
            specs = [];
        end

        function specs = parseSidecarFile(~, filePath)
            specs = nansen.unittest.plugin.fixture.TestSpec.fromJsonFile(filePath);
        end

        function specs = emptySpecArray(~)
            specs = nansen.unittest.plugin.fixture.TestSpec.empty;
        end

    end
end
