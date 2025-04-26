classdef Joystick < handle
    %JOYSTICK  Encapsulates polling of a joystick via a web API

    properties
        id      % Joystick identifier
        bl      % Button left state
        br      % Button right state
        xl      % X-axis left
        yl      % Y-axis left
        xr      % X-axis right
        url     % API URL for polling
        options % weboptions object for webread
    end

    methods
        function obj = Joystick(id, port)
            %Joystick Construct a Joystick handle with given id and port
            obj.id = id;
            obj.url = sprintf('http://localhost:%d/api/joystick/%d', port, id);
            obj.options = weboptions('Timeout', 0.1, 'ContentType', 'json');
        end

        function pollJoystick(obj)
            %pollJoystick Query the joystick API and update properties
            js = webread(obj.url, obj.options);
            obj.bl = js.bl;
            obj.br = js.br;
            obj.xl = js.xl;
            obj.yl = js.yl;
            obj.xr = js.xr;
        end
    end
end
