classdef tabButton < uim.style.buttonScheme
    
    properties (Constant)
        
        HighlightedOn = struct(...
            'ForegroundColor', ones(1,3) * 0, ...
            'BackgroundColor', ones(1,3) * 0.8, ...
            'BackgroundAlpha', 1, ...
            'BorderColor', 'none', ...
            'BorderWidth', 0.6)
        HighlightedOff = struct(...
            'ForegroundColor', ones(1,3) * 0.95, ...
            'BackgroundColor', ones(1,3) * 0.2, ...
            'BackgroundAlpha', 0, ...
            'BorderColor', 'none', ...
            'BorderWidth', 0.5)
        On = struct(...
            'ForegroundColor', ones(1,3) * 0, ...
            'BackgroundColor', ones(1,3) * 0.8, ...
            'BackgroundAlpha', 1, ...
            'BorderColor', 'none', ...
            'BorderWidth', 0.5)
        Off = struct(...
            'ForegroundColor', ones(1,3) * 0.8, ...
            'BackgroundColor', ones(1,3) * 0.4, ...
            'BackgroundAlpha', 0, ...
            'BorderColor', 'none', ...
            'BorderWidth', 0.5)
    end
end
