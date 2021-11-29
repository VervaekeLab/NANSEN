# dark mode plot 
[![View dark mode plot  on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/86533-dark-mode-plot)



Transform your MATLAB plots to fit dark mode theme backgrounds! The function test which of the figure colors are not suitable to be used over a dark background (via color contrast), and adjust colors accordingly using a desaturation and brightness approach. In addition, it transforms the relevant Matlab figure attributes, such as axis and text colors, and figure background. The result is a transformed figure that can be copied to a dark mode theme presentation or website.

Preparing this function I was inspired by https://material.io/design/color/dark-theme.html


  
How to use the function:
generate or import a Matlab figure and run the function, for example:

       plot(bsxfun(@times,[1:4],[2:5]'));xlabel('X');ylabel('Y');
       plot_darkmode

Copy the figure from the clipboard using *Edit>Copy Figure* and paste it on top of the dark background theme, for example in PowerPoint. Make sure that in the *Copy Option*, the *Transparent Background* is enabled. The function was tested with Matlab 2019b - Win10.



  ![plot](./plot_darkmode_img.png)

Known bugs:
1. surf plot works on screen, but fails in the copy-paste procedure.

To Do:
1. write a version of the sub function adjust_color to adjust colormaps based on similar reasoning, (or replace colormaps?)
