function [jFrame, jLabel, C] = showSplashScreen(imFilePath, titleStr, subTitleStr)
%showSplashScreen Show image in splash window with title and subtitle.
%
%   [jFrame, jLabel, C] = showSplashScreen(imFilePath, titleStr, subTitleStr)
%
%   INPUTS:
%       imFilePath : Filepath to image to display
%       titleStr : Textstring for title to display
%       subTitleStr : Textstring for subtitle to display
%
%   OUTPUTS:
%       jFrame : Handle to the java frame.
%       jLabel : Handle to java label. Tip: jLabel.setString('Hellow
%                world') to update text
%       C : Cleanup object. When this variable is cleared, the splash
%           window is deleted

% Todo: Make class

% Inspired by Microscopy Image Browser
    
    if nargin < 3; subTitleStr = ''; end
    
    im = imread(imFilePath);
    
    warning('off', 'MATLAB:im2java:functionToBeRemoved')
    jImage = im2java(im);
    warning('on', 'MATLAB:im2java:functionToBeRemoved')
    jFrame = javax.swing.JFrame;
    jFrame.setUndecorated(true);
    
    imSize = size(im);
    
    % Add panel to frame
%     JPanel = javax.swing.JPanel();
%     jFrame.add(JPanel);
    
    icon = javax.swing.ImageIcon(jImage);
    jBackgroundLabel = javax.swing.JLabel(icon);
    jBackgroundLabel.setBounds(0, 0, imSize(2), imSize(1))
    jFrame.getContentPane.add(jBackgroundLabel);
    
    %jFrame.add(label);
    % add label to panel
    %JPanel.add(label);
           
    jLabelTitle = javax.swing.JLabel(titleStr);
    jLabelTitle.setForeground( java.awt.Color(0.1882, 0.2431, 0.2980) )
    jLabelTitle.setBounds(25, 30, 200, 40);
    
    titleFont = java.awt.Font('Lucida Grande', java.awt.Font.PLAIN, 30);
    set(jLabelTitle, 'Font', titleFont);
    
    jLabel = javax.swing.JLabel(subTitleStr);
    jLabel.setForeground( java.awt.Color(0.1882, 0.2431, 0.2980) )
    jLabel.setBounds(35, 70, 250, 25);
    
    imPath = fullfile(nansen.toolboxdir, 'resources', 'images', 'loading.gif');
    jIcon2 = javax.swing.ImageIcon(imPath);
    jLabelLoadGif = javax.swing.JLabel(jIcon2);
    jLabelLoadGif.setBounds(5, 100, 112, 112);
    
    jBackgroundLabel.add(jLabelTitle);
    jBackgroundLabel.add(jLabel);
    jBackgroundLabel.add(jLabelLoadGif);
    
    
    footerText = {'Version 1.0.0 - alpha', 'Created by Eivind Hennestad', 'Vervaeke Lab of Neural Computation', 'University of Oslo'};
    footerText = sprintf( "<html>%s</html>", strjoin(footerText, '<br>'));
    
    fgRGB = [0.9176, 0.9255, 0.9294];
    jLabelFooter = javax.swing.JLabel(footerText);
    %jLabelFooter.setText(footerText)
    jLabelFooter.setForeground( java.awt.Color(fgRGB(1), fgRGB(2), fgRGB(3)) )
    jLabelFooter.setBounds(10, 320, 250, 60);
    
    jLabelFooter.setVerticalAlignment(javax.swing.JLabel.TOP);
    jLabelFooter.setHorizontalAlignment(javax.swing.JLabel.LEFT);
    
    titleFont = java.awt.Font('Avenir Next', java.awt.Font.PLAIN, 10);
    set(jLabelFooter, 'Font', titleFont);
    
    jBackgroundLabel.add(jLabelFooter);
    
    

    % Set size of frame
    jFrame.setSize(imSize(2),imSize(1));
    
    % Place in center of screen
    screenSize = get(0,'ScreenSize');
    jFrame.setLocation((screenSize(3)-imSize(2))/2,...
        (screenSize(4)-imSize(1))/2);
    
    % Prepare and show
    jFrame.pack();
    jFrame.show;
    
    C = onCleanup(@(jH)closeSplashScreen(jFrame));

end

function closeSplashScreen(jFrame)
    jFrame.dispose();
    jFrame.setVisible(false);
end