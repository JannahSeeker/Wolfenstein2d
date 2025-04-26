function runRaycasterDemo()
    % Basic Raycaster Demo using renderMex engine
    % Input handling is performed by C++/Raylib via renderGetInputState()

    % --- Configuration ---
    screenWidth = 800;
    screenHeight = 600;
    mapWidth = 16;
    mapHeight = 16;

    map = [ % Define the map (0=empty, 1-4=wall types)
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1;
        1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
        1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
        1,0,0,1,1,0,0,0,2,2,0,0,0,0,0,1;
        1,0,0,1,0,0,0,0,2,0,0,0,0,0,0,1;
        1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
        1,0,0,0,0,0,3,3,3,3,0,0,0,0,0,1;
        1,0,0,0,0,0,3,0,0,3,0,0,0,0,0,1;
        1,0,0,0,0,0,3,0,0,3,0,0,0,0,0,1;
        1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1;
        1,0,2,0,0,0,0,0,0,4,4,4,4,0,0,1;
        1,0,2,0,0,0,0,0,0,0,0,0,0,0,0,1;
        1,0,2,2,2,2,0,0,0,0,0,0,0,0,0,1;
        1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
        1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1;
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1;
    ];

    % Player initial state
    playerX = 3.5; % x position
    playerY = 3.5; % y position
    playerA = pi/4; % angle (radians)
    fov = pi / 3;   % field of view (~60 degrees)
    moveSpeed = 2.0; % units per second
    rotSpeed = 1.5;  % radians per second

    % Colors
    colorWall1 = uint8([200, 0, 0, 255]);   % Red
    colorWall2 = uint8([0, 200, 0, 255]);   % Green
    colorWall3 = uint8([0, 0, 200, 255]);   % Blue
    colorWall4 = uint8([200, 200, 200, 255]); % Gray
    colorWallNS1 = uint8([140, 0, 0, 255]); % Darker Red (N/S Walls)
    colorWallNS2 = uint8([0, 140, 0, 255]); % Darker Green
    colorWallNS3 = uint8([0, 0, 140, 255]); % Darker Blue
    colorWallNS4 = uint8([140, 140, 140, 255]);% Darker Gray
    colorFloor = uint8([80, 80, 80, 255]);    % Dark Gray
    colorCeiling = uint8([120, 120, 120, 255]);% Lighter Gray
    colorText = uint8([0, 255, 0, 255]);    % Green

    % --- Initialization ---
    if ~renderInit(screenWidth, screenHeight)
        error('Failed to initialize renderer.');
    end

    fpsString = 'FPS: ---';
    lastTime = tic; % Timer for frame duration calculation

    % --- Main Loop ---
    disp('Starting Raycaster Demo Loop... Focus the render window.');
    while ~renderShouldClose() % Check if figure still exists and user hasn't clicked X

        % -- Timing --
        currentTime = tic;
        deltaTime = toc(lastTime);
        lastTime = currentTime;
        deltaTime = min(deltaTime, 0.1); % Clamp delta time to prevent large jumps

        % --- Get Input State from C++ ---
        inputState = renderGetInputState(); % Calls renderMex('getInputState')

        % --- Check for Exit Request ---
        if inputState.Exit % Check the .Exit field from the returned struct
            disp('Exit key (Escape) pressed.');
            break; % Exit the main while loop
        end
            
        % --- Process Input based on returned struct ---
        moveForward = 0;
        rotate = 0;
        if inputState.RotateLeft, rotate = -1; end
        if inputState.RotateRight, rotate = 1; end
        if inputState.MoveForward, moveForward = 1; end
        if inputState.MoveBackward, moveForward = -1; end

        % -- Update Player State (Movement/Rotation) --
        if rotate ~= 0
            playerA = playerA + rotate * rotSpeed * deltaTime;
        end

        if moveForward ~= 0 % || strafe ~= 0 % Add strafe condition if using it
            moveStep = moveForward * moveSpeed * deltaTime;
            % strafeStep = strafe * moveSpeed * deltaTime; % If using strafe
            dirX = cos(playerA);
            dirY = sin(playerA);
            % strafeX = -dirY; % Strafe vector X component
            % strafeY = dirX;  % Strafe vector Y component

            % Calculate combined movement vector components
            deltaX = dirX * moveStep; % + strafeX * strafeStep;
            deltaY = dirY * moveStep; % + strafeY * strafeStep;

            newX = playerX + deltaX;
            newY = playerY + deltaY;

            % Collision Detection (checking target cells before moving)
            mapCheckX_X = floor(newX); % Target X cell when moving X component
            mapCheckY_X = floor(playerY);% Current Y cell when moving X component
            mapCheckX_Y = floor(playerX);% Current X cell when moving Y component
            mapCheckY_Y = floor(newY); % Target Y cell when moving Y component

            % Check X movement component allows move
            if newX > 0.1 && newX < mapWidth-0.1 ... % Check bounds slightly inset
               && mapCheckY_X >= 1 && mapCheckY_X <= mapHeight ...
               && mapCheckX_X >= 1 && mapCheckX_X <= mapWidth ...
               && map(mapCheckY_X, mapCheckX_X) == 0
                 playerX = newX; % Allow X movement
            end
             % Check Y movement component allows move (use potentially updated playerX)
             mapCheckX_Y = floor(playerX); % Update check coord based on allowed X move
             if newY > 0.1 && newY < mapHeight-0.1 ... % Check bounds slightly inset
                && mapCheckX_Y >=1 && mapCheckX_Y <= mapWidth ...
                && mapCheckY_Y >= 1 && mapCheckY_Y <= mapHeight ...
                && map(mapCheckY_Y, mapCheckX_Y) == 0
                 playerY = newY; % Allow Y movement
             end
        end

        % -- Rendering --
        renderBeginFrame();

        % Floor and Ceiling
        renderDrawRect(0, 0, screenWidth, screenHeight/2, colorCeiling);
        renderDrawRect(0, screenHeight/2, screenWidth, screenHeight/2, colorFloor);

        % Raycasting Loop (Full DDA logic included for completeness)
        for x = 1:screenWidth
            % Calculate ray properties
            cameraX = 2 * (x-1) / (screenWidth - 1) - 1;
            rayDirX = cos(playerA) - sin(playerA) * cameraX * tan(fov/2);
            rayDirY = sin(playerA) + cos(playerA) * cameraX * tan(fov/2);

            % Map position and deltas
            mapX = floor(playerX); mapY = floor(playerY);
            deltaDistX = abs(1 / rayDirX) + 1e-10; deltaDistY = abs(1 / rayDirY) + 1e-10;

            % Step and initial side distances
            hit = false; side = 0; perpWallDist = 0;
            if (rayDirX < 0), stepX = -1; sideDistX = (playerX - mapX) * deltaDistX; else stepX = 1; sideDistX = (mapX + 1.0 - playerX) * deltaDistX; end
            if (rayDirY < 0), stepY = -1; sideDistY = (playerY - mapY) * deltaDistY; else stepY = 1; sideDistY = (mapY + 1.0 - playerY) * deltaDistY; end

            % Digital Differential Analyzer (DDA)
            while (~hit)
                if (sideDistX < sideDistY)
                    sideDistX = sideDistX + deltaDistX; mapX = mapX + stepX; side = 0;
                else
                    sideDistY = sideDistY + deltaDistY; mapY = mapY + stepY; side = 1;
                end
                % Check bounds or wall hit
                if mapX < 1 || mapX > mapWidth || mapY < 1 || mapY > mapHeight
                    hit = true; perpWallDist = 1e6; % Hit boundary, treat as far
                elseif map(mapY, mapX) > 0 % Check map data for wall
                    hit = true;
                end
            end % End DDA

            % Calculate distance (correcting fisheye if wall hit)
            if (hit && perpWallDist < 1e5)
                if (side == 0)
                    perpWallDist = (mapX - playerX + (1 - stepX) / 2.0) / rayDirX;
                else
                    perpWallDist = (mapY - playerY + (1 - stepY) / 2.0) / rayDirY;
                end
            end
            if perpWallDist <= 0.1, perpWallDist = 0.1; end % Clamp distance

            % Calculate wall slice properties
            lineHeight = floor(screenHeight / perpWallDist);
            drawStart = max(0, -lineHeight / 2 + screenHeight / 2);
            drawEnd = min(screenHeight - 1, lineHeight / 2 + screenHeight / 2);

            % Determine wall color and shading
            wallType = 0;
            if mapX >= 1 && mapX <= mapWidth && mapY >= 1 && mapY <= mapHeight
                 wallType = map(mapY, mapX);
            end
            wallColor = Mux(wallType == 1, Mux(side==1, colorWallNS1, colorWall1), ...
                        Mux(wallType == 2, Mux(side==1, colorWallNS2, colorWall2), ...
                        Mux(wallType == 3, Mux(side==1, colorWallNS3, colorWall3), ...
                        Mux(wallType == 4, Mux(side==1, colorWallNS4, colorWall4), uint8([50 50 50 255]))))); % Default dark grey

            % Draw the wall slice using renderDrawRect
            renderDrawRect(x-1, floor(drawStart), 1, floor(drawEnd) - floor(drawStart) + 1, wallColor);

        end % end raycasting loop (for x)

        % Draw FPS/Info/Mouse Text
        if deltaTime > 0, fps = 1.0 / deltaTime; fpsString = sprintf('FPS: %.1f', fps); end
        renderDrawText(fpsString, 10, 10, 20, colorText);
        posString = sprintf('X:%.2f Y:%.2f A:%.2f', playerX, playerY, playerA);
        renderDrawText(posString, 10, 35, 20, colorText);
        mouseString = sprintf('Mouse: %.0f, %.0f L:%d R:%d', inputState.MouseX, inputState.MouseY, inputState.MouseLeft, inputState.MouseRight);
        renderDrawText(mouseString, 10, 60, 20, colorText); % Display mouse info

        renderEndFrame();

        % --- Yield CPU and process events ---
        drawnow limitrate;

    end % end main loop

    renderShutdown();
    disp('Raycaster Demo finished.');

% --- Helper function Mux ---
    function result = Mux(condition, value_if_true, value_if_false)
        if condition
            result = value_if_true;
        else
            result = value_if_false;
        end
    end

end % function runRaycasterDemo

runRaycasterDemo()