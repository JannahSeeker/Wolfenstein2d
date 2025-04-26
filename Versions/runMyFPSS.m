function runMyFPSS()
    %RUNMYFPSS  Head‑less launcher that runs each loop on its own background
    %           worker (parfeval) and prints minimal status to the console.
    %
    %   Stops when the user presses ENTER or when gameState.running == false.
        % Colors
        gs = initGameState();

        % colorWall1 = uint8([200, 0, 0, 255]);   % Red
        % colorWall2 = uint8([0, 200, 0, 255]);   % Green
        % colorWall3 = uint8([0, 0, 200, 255]);   % Blue
        % colorWall4 = uint8([200, 200, 200, 255]); % Gray
        % colorWallNS1 = uint8([140, 0, 0, 255]); % Darker Red (N/S Walls)
        % colorWallNS2 = uint8([0, 140, 0, 255]); % Darker Green
        % colorWallNS3 = uint8([0, 0, 140, 255]); % Darker Blue
        % colorWallNS4 = uint8([140, 140, 140, 255]);% Darker Gray
        % colorFloor = uint8([80, 80, 80, 255]);    % Dark Gray
        % colorCeiling = uint8([120, 120, 120, 255]);% Lighter Gray
        % colorText = uint8([0, 255, 0, 255]);    % Green
        % %% 1) Build all state
 
        % screenWidth = 800;
        % screenHeight = 600;
        % mapWidth = gs.mapManager.width;
        % mapHeight = gs.mapManager.height;
        % fov = pi / 3;   % field of view (~60 degrees)
    

    
        %% 3) Launch background tasks
        % raycaster3d(gs);

        runRaycaster(gs);

        % fInput  = parfeval(@input2Loop,  0, gs);   % 0 outputs
        % fLogic  = parfeval(@logicLoop,  0, gs);
        % fRender = parfeval(@render2dLoop, 0, gs);   % renderLoop can discard frames
    

        fprintf("Shutdown complete.\n");
    end