% NANSEN.INTERNAL.SETUP - Helpers for preparing the MATLAB environment for NANSEN
%
% Things we have to fix up before NANSEN can run cleanly: an empty
% userpath, missing jars on the Java class path, a too-old Widgets Toolbox.
%
% Functions
%   resolveEmptyUserpath            - Set userpath if it is empty (Linux)
%   addYamlJarToJavaClassPath       - Add the YAML-Matlab jar to the Java class path
%   addUiwidgetsJarToJavaClassPath  - Add the Widgets Toolbox jar to the Java class path
%   isUiwidgetsOnJavapath           - True if the Widgets Toolbox jar is on the Java class path
%   checkWidgetsToolboxVersion      - Verify the installed Widgets Toolbox version
