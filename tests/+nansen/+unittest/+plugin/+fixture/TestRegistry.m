classdef TestRegistry < nansen.plugin.base.Registry
%TestRegistry Minimal concrete Registry used in Phase 1 foundation tests.
%
%   This class exists solely for unit testing. It must not be used in
%   production code.

    properties (Constant, Access = protected)
        PluginType      = nansen.plugin.enum.PluginType.FileAdapter
        SidecarFilename = "test.plugin.json"
    end

    properties
        % ParseCount - Number of times a sidecar file was actually parsed
        %   (not served from the mtime cache). Reset by calling clear().
        ParseCount (1,1) double = 0

        % RootPath - The single root path scanned for sidecars.
        RootPath (1,1) string = ""
    end

    methods

        function obj = TestRegistry(rootPath, projectFolder)
        %TestRegistry Construct with an explicit root path for testing.
            arguments
                rootPath      (1,1) string = ""
                projectFolder (1,1) string = ""
            end
            obj@nansen.plugin.base.Registry(projectFolder)
            obj.RootPath = rootPath;
        end

        function clear(obj)
        %clear Reset registry state including the parse counter.
            clear@nansen.plugin.base.Registry(obj)
            obj.ParseCount = 0;
        end
    end

    methods (Access = protected)

        function roots = getRootPaths(obj)
            roots = {char(obj.RootPath)};
        end

        function specs = discoverCompatibilitySpecs(~)
        %discoverCompatibilitySpecs No compat discovery for the test fixture.
            specs = [];
        end

        function specs = parseSidecarFile(obj, filePath)
        %parseSidecarFile Parse a sidecar and increment the parse counter.
            obj.ParseCount = obj.ParseCount + 1;
            specs = nansen.unittest.plugin.fixture.TestSpec.fromJsonFile(filePath);
        end
    end
end
