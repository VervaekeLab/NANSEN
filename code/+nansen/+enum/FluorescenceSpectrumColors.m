classdef FluorescenceSpectrumColors

    enumeration
        FARRED('farred')
        RED('red')
        CRIMSON('crimson')
        ORANGE('orange')
        YELLOW('yellow')
        GREEN('green')
        CYAN('cyan')
        BLUE('blue')
        INDIGO('indigo')
        VIOLET('violet')
    end

    % Properties
    properties (SetAccess=immutable)
        Name
        Label
        LongLabel
        WaveLength
        Rgb
        WaveLengthInterval
    end

    properties (Constant)
        WaveLengthUnit = 'nm'
    end

    methods
        
        function obj = FluorescenceSpectrumColors(name)
            
            obj.Name = name;

            switch obj.Name
                case 'farred'
                    obj.Label = 'Far Red';
                    obj.WaveLength = 685;
                case 'red'
                    obj.Label = 'Red';
                    obj.WaveLength = 655;
                case 'crimson'
                    obj.Label = 'Crimson';
                    obj.WaveLength = 625;
                case 'orange'
                    obj.Label = 'Orange';
                    obj.WaveLength = 595;
                case 'yellow'
                    obj.Label = 'Yellow';
                    obj.WaveLength = 565;
                case 'green'
                    obj.Label = 'Green';
                    obj.WaveLength = 535;
                case 'cyan'
                    obj.Label = 'Cyan';
                    obj.WaveLength = 505;
                case 'blue'
                    obj.Label = 'Blue';
                    obj.WaveLength = 475;
                case 'indigo'
                    obj.Label = 'Indigo';
                    obj.WaveLength = 445;
                case 'violet'
                    obj.Label = 'Violet';
                    obj.WaveLength = 415;
            end

            obj.WaveLengthInterval = [obj.WaveLength] + [-15, 15];
            obj.Rgb = spectrumRGB(obj.WaveLength);
            obj.LongLabel = sprintf('%s (%d-%d nm)', obj.Label, ...
                obj.WaveLengthInterval(1), obj.WaveLengthInterval(2));
        end
        
    end
    
end