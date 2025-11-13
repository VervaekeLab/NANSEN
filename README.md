<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/VervaekeLab/NANSEN/assets/17237719/2a891edd-8f80-4253-a699-ab37f9cd6b42">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/VervaekeLab/NANSEN/assets/17237719/2a891edd-8f80-4253-a699-ab37f9cd6b42">
    <img alt="Neuro Analysis Software Ensemble" src="https://github.com/VervaekeLab/NANSEN/assets/17237719/2a891edd-8f80-4253-a699-ab37f9cd6b42" title="Neuro Analysis Software Ensemble" align="right" height="70" width="70px">
</picture>

# NANSEN - Neuro ANalysis Software ENsemble
[![YouTube](https://img.shields.io/youtube/channel/views/UCKOzL-MVWgy7oOMo6x_GSkQ?style=social)](https://www.youtube.com/channel/UCKOzL-MVWgy7oOMo6x_GSkQ)

[![Codespell](https://github.com/VervaekeLab/NANSEN/actions/workflows/run_codespell.yml/badge.svg?branch=add%2Fdeveloper-tools)](https://github.com/VervaekeLab/NANSEN/actions/workflows/run_codespell.yml)

A collection of apps and modules for processing, analysis and visualization of two-photon imaging data. Check out the introduction to Nansen on [YouTube](https://youtu.be/_u0Aw1n5gHg) and/or see the [Wiki](https://github.com/VervaekeLab/NANSEN/wiki) for more details!

<img src="https://user-images.githubusercontent.com/17237719/201542036-3be1b9b2-b59c-4e2d-9104-52f6d3806f02.gif?raw=true" alt="Session table demo" width="100%"/>
<!---
<img src="https://github.com/ehennestad/ehennestad.github.io/blob/main/images/app_overview.png?raw=true" alt="Imviewer instance" width="100%"/>
--->

## Contents

- [Installation](#installation)
- [Apps](#apps)
    - [Imviewer](#imviewer)
    - [Fovmanager](#fovmanager)
- [Plugins](#plugins)
- [Wiki](https://github.com/VervaekeLab/NANSEN/wiki)


## Disclaimer
The NANSEN toolbox is still under development, so don't be surprised if you find occasional bugs here and there! If you manage to break something, please report under the issues section! Also, suggestions for improvements and general feedback are very welcome!

## Requirements
- MATLAB Release 2020b or later is recommended.
- NANSEN is not compatible with R2025a or newer yet; support is planned for 2026.

## Installation
 1) Clone the repository and add all subfolders to MATLAB's search path. 
 2) Make sure the required MATLAB toolboxes ([listed below](#required-matlab-toolboxes)) are installed.
 3) Run `nansen.setup` to install community toolboxes and configure your first project. Alternative: To use nansen apps without creating a project, install the required community toolboxes ([listed below](#required-community-toolboxes)). View demo of `nansen.setup` on [YouTube](https://www.youtube.com/watch?v=lVx-x6Lqvp4&t=4s).

### Required Matlab toolboxes
 - Image Processing Toolbox
 - Statistics and Machine Learning Toolbox
 - Parallel Computing Toolbox
 - Signal Processing Toolbox

To check if these toolboxes are already installed, use the `ver` command. 
Typing `ver` in matlab's command window will display all installed toolboxes. 
If any of the above toolboxes are not installed, they can be installed by 
navigating to MATLAB's Home tab and then selecting Add-Ons > Get Add-Ons

### Required community toolboxes
<!---
- GUI Layout Toolbox ([View toolbox site](https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox))
---> 
 - Widgets Toolbox** ([Download toolbox installer](https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/b0bebf59-856a-4068-9d9c-0ed8968ac9e6/099f0a4d-9837-4e5f-b3df-aa7d4ec9c9c9/packages/mltbx) | [View toolbox site](https://se.mathworks.com/matlabcentral/fileexchange/66235-widgets-toolbox-compatibility-support?s_tid=srchtitle))

** The Widgets Toolbox can also be installed using MATLAB's addon manager, 
but it is important to install a compatibility version (v1.3.330) of the 
toolbox, so please use the download link above or install using `nansen.setup`.

## Apps

### Imviewer
App for viewing and interacting with videos & image stacks

<img src="https://ehennestad.github.io/images/imviewer.png" alt="Imviewer instance" width="500"/>

### Fovmanager
App for registering cranial implants, injection spots and imaging field of views (and RoIs) on an atlas of the dorsal surface of the cortex.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://user-images.githubusercontent.com/17237719/197357426-248bc6e4-cbe4-4f80-9fae-3d54382edcd9.png">
  <source media="(prefers-color-scheme: light)" srcset="https://ehennestad.github.io/images/fovmanager.png">
  <img alt="Fovmanager." src="https://ehennestad.github.io/images/fovmanager.png" width="500">
</picture>

## Plugins
Example of toolbox plugins that are included in NANSEN

<img src="https://github.com/ehennestad/ehennestad.github.io/blob/main/images/plugin_examples.png?raw=true" alt="Imviewer instance" width="100%"/>


