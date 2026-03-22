% Overview of nansen.internal.setup namespace
% Environment setup utilities for NANSEN.
%
% This package contains setup-time helpers for preparing the MATLAB
% environment, userpath, Java class path, and other runtime prerequisites.
%
% Functions
%   resolveEmptyUserpath            - Resolve missing MATLAB userpath.
%   addYamlJarToJavaClassPath       - Add YAML jar to Java class path.
%   addUiwidgetsJarToJavaClassPath  - Add Widgets Toolbox jar to Java path.
%   isUiwidgetsOnJavapath           - Check Widgets Toolbox Java path setup.
%   checkWidgetsToolboxVersion      - Check Widgets Toolbox version.
