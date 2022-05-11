# NANSEN - Neuro ANalysis Software ENsemble
[![Twitter](https://img.shields.io/twitter/follow/NeuroNansen?style=social)](https://twitter.com/NeuroNansen)
[![YouTube](https://img.shields.io/youtube/channel/views/UCKOzL-MVWgy7oOMo6x_GSkQ?style=social)](https://www.youtube.com/channel/UCKOzL-MVWgy7oOMo6x_GSkQ)

A collection of apps and modules for processing, analysis and visualization of two-photon imaging data. Check out the introduction to Nansen on [YouTube](https://youtu.be/BrTENBn4wFs)

<img src="https://github.com/ehennestad/ehennestad.github.io/blob/main/images/app_overview.png?raw=true" alt="Imviewer instance" width="100%"/>

## Installation
Currently, the only actions that are needed is:
 1) Clone the repository and add all subfolders to MATLAB's search path. 
 2) Make sure the dependencies listed below are installed

Note: As more modules and toolboxes are added in the next weeks and months, 
these lists will get updated.

### Required Matlab toolboxes
 - Image Processing Toolbox
 - Statistics and Machine Learning Toolbox
 - Parallel Computing Toolbox

To check if these toolboxes are already installed, use the `ver` command. 
Typing `ver` in matlab's command window will display all installed toolboxes. 
If any of the above toolboxes are not installed, they can be installed by 
navigating to MATLAB's Home tab and then selecting Add-Ons > Get Add-Ons

### Other toolboxes
 - GUI Layout Toolbox ([View toolbox site](https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox))
 - Widgets Toolbox ([Download toolbox installer](https://se.mathworks.com/matlabcentral/mlc-downloads/downloads/b0bebf59-856a-4068-9d9c-0ed8968ac9e6/099f0a4d-9837-4e5f-b3df-aa7d4ec9c9c9/packages/mltbx) | [View toolbox site](https://se.mathworks.com/matlabcentral/fileexchange/66235-widgets-toolbox-compatibility-support?s_tid=srchtitle))


These toolboxes can also be installed using MATLAB's addon manager, but it 
is important to install a compatibility version (v1.3.330) of the Widgets Toolbox, 
so please use the download link above.

## Apps

### Imviewer
App for viewing and interacting with videos & image stacks

<img src="https://ehennestad.github.io/images/imviewer.png" alt="Imviewer instance" width="500"/>

### Fovmanager
App for registering cranial implants, injection spots and imaging field of views (and RoIs) on an atlas of the dorsal surface of the cortex.

<img src="https://ehennestad.github.io/images/fovmanager.png" alt="Imviewer instance" width="500"/>

## Plugins
Example of toolbox plugins that are included in NANSEN

<img src="https://github.com/ehennestad/ehennestad.github.io/blob/main/images/plugin_examples.png?raw=true" alt="Imviewer instance" width="100%"/>

\* Awaiting publication


