classdef AddonManagerFixture < matlab.unittest.fixtures.Fixture
%AddonManagerFixture Fixture for creating an isolated AddonManager for testing.
%
%   Creates a singleton AddonManager backed by a temporary installation
%   folder and manifest file. The constructor only loads persisted state
%   (no manifest discovery), then the fixture calls refreshManagedAddons
%   with explicit test manifest paths.
%
%   On teardown, resets the singleton so subsequent tests get a fresh
%   instance.
%
%   By default, the fixture resolves dependencies from the test manifests
%   shipped in tests/+nansen/+fixture/manifests/. Pass custom
%   DependencyManifestPaths to override.
%
%   Example:
%       fixture = testCase.applyFixture(nansen.fixture.AddonManagerFixture);
%       manager = fixture.AddonManager;

    properties (SetAccess = private)
        % InstallationFolder - Temporary folder for addon installation
        InstallationFolder (1,1) string

        % ManifestFilePath - Temporary path for the installed_addons.json
        ManifestFilePath (1,1) string

        % AddonManager - The singleton instance created by this fixture
        AddonManager
    end

    properties (Access = private)
        DependencyManifestPaths (1,:) string
    end

    methods
        function fixture = AddonManagerFixture(options)
        %AddonManagerFixture Create a fixture with optional custom manifests.
            arguments
                options.DependencyManifestPaths (1,:) string = string.empty
            end
            fixture.DependencyManifestPaths = options.DependencyManifestPaths;
        end
    end

    methods
        function setup(fixture)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            temporaryFolderFixture = fixture.applyFixture(TemporaryFolderFixture);
            fixture.InstallationFolder = fullfile(temporaryFolderFixture.Folder, 'Add-Ons');
            mkdir(fixture.InstallationFolder);
            fixture.ManifestFilePath = nansen.config.addons.getAddonManifestFilePath( ...
                fixture.InstallationFolder);

            dependencyManifestPaths = fixture.DependencyManifestPaths;
            if isempty(dependencyManifestPaths)
                dependencyManifestPaths = fixture.getDefaultTestManifestPaths();
            end

            % Create singleton with clean state (no manifest discovery)
            fixture.AddonManager = nansen.config.addons.AddonManager.instance( ...
                "reset", "AddonFolder", fixture.InstallationFolder);

            % Populate from test manifests only
            fixture.AddonManager.refreshManagedAddons( ...
                "ManifestPaths", dependencyManifestPaths);

            fixture.addTeardown(@() nansen.config.addons.AddonManager.instance("clear"));
        end
    end

    methods (Access = protected)
        function isCompatibleResult = isCompatible(fixture, other)
        %isCompatible Two fixtures are compatible if they use the same manifest paths.
            isCompatibleResult = isequal( ...
                fixture.DependencyManifestPaths, other.DependencyManifestPaths);
        end
    end

    methods (Static, Access = private)
        function manifestPaths = getDefaultTestManifestPaths()
        %getDefaultTestManifestPaths Return paths to the bundled test manifests.
            manifestDirectory = fullfile( ...
                fileparts(mfilename('fullpath')), 'manifests');
            manifestPaths = string({ ...
                fullfile(manifestDirectory, 'test_core_dependencies.nansen.json'), ...
                fullfile(manifestDirectory, 'test_module_dependencies.nansen.json') });
        end
    end
end
