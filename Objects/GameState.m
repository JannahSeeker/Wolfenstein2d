classdef GameState < handle
    %GAMESTATE  Master game‐state object (handle class).

    properties
        players Player = Player.empty(1,0);
        mapManager     % MapManager object
        spriteManager  % SpriteManager object
        running    (1,1) logical = true
        renderPeriod  double = 1/60
        logicPeriod   double = 1/30
        inputPeriod   double = 1/100
        leaderboard
        serverClient        % tcpclient connection to Python game server
        networkBuffer char = ''   % buffer for partial TCP reads
        client_id 
        joystick_server_url string = "http://127.0.0.1:5100/api"
    end

    methods
        function obj = GameState()
            % Construct all sub‐objects
            obj.mapManager    = MapManager(obj);
            obj.spriteManager = SpriteManager(obj);
            % Initialize TCP client to Python server on port 5555
            obj.serverClient = tcpclient('127.0.0.1', 5555, 'Timeout', 0.1);
            obj.leaderboard = struct('name', {}, 'time', {});  % start empty
            % === connect & read handshake ===
            line = readline(obj.serverClient);                   % blocks until server’s handshake_ack
            msg  = jsondecode(char(line));        % struct with .type and .payload
            
            obj.client_id = msg.payload.client_id;    % “handshake_ack”
            % === immediately register as the MATLAB logic server ===

        end

        function authorizeMatlabServer(obj)
            regMsg = struct( ...
                'type',    'register_matlab', ...
                'payload', struct() ...           % no extra data needed
                );
            writeline(obj.serverClient, jsonencode(regMsg));     % sends '{"type":"register_matlab","payload":{}}\n'
        end
        function createJoystick(obj, joystick_id)
            %CREATEJOYSTICK  Sends a GET request to create a joystick via the web API.
            % Build the full URL, ensuring joystick_id is converted to string
            url = obj.joystick_server_url + "/createJoystick/" + num2str(joystick_id);
            try
                % Use webread for a GET request; no need to specify MediaType for JSON GET
                response = webread(url, weboptions('Timeout', 5));
                % Optionally handle response if needed
            catch err
                warning("Failed to create joystick (ID %d): %s", joystick_id, err.message);
            end
        end

        function addPlayer(obj, id, joystick_id, port)
            % Dynamically add another player at runtime
            p = Player(obj);
            p.id = id;
            obj.createJoystick(joystick_id);
            p.bindJoystick(joystick_id, port);
            disp(p);
            obj.players(end+1) = p;
        end
        function removePlayer(obj, id)
            % Remove player #idx
            idx = find([obj.players.id] == id, 1);
            if isempty(idx)
                return
            end
            obj.players(idx) = [];
        end
        function updatePlayers(obj, dt)
            % Poll and move each player based on their bound joystick
            for p = obj.players
                p.updateFromJoystick(dt);
            end
            obj.syncWithServer();
        end
        function updateSprites(obj, dt)
            % Advance all sprite AIs
            for s = obj.spriteManager.sprites
                if ~isempty(obj.players)
                    s.update(obj.players, obj.mapManager, dt);
                end
                % If you want sprites to see all players, you could pass the
                % entire players array instead of just one.
            end
        end

        function playerWin(obj, id)
            %PLAYERWIN  Record a finishing player into the leaderboard and sort by time
            idx = find([obj.players.id] == id, 1);
            if isempty(idx)
                return;   % no such player
            end
            p = obj.players(idx);
            % Assume each Player has .name an\d .finishTime properties:
            entry = struct( ...
                'name', p.name, ...
                'time', p.endTime ...
                );
            % Append
            obj.leaderboard(end+1) = entry;
            % Sort ascending by time
            times = [obj.leaderboard.time];
            [~, order] = sort(times);
            obj.leaderboard = obj.leaderboard(order);
            obj.removePlayer(id);
        end
        function playerLose(obj, id)
            %PLAYERWIN  Record a finishing player into the leaderboard and sort by time
            % Assume each Player has .name and .finishTime properties:
            obj.removePlayer(id);
        end

        function handleSpritePlayerCollisions(obj)
            for s = obj.spriteManager.sprites
                for p = obj.players
                    % only check if both are alive/in the same floor
                    if ~p.isDead && s.pos(3)==p.position(3)
                        dx = s.pos(1) - p.position(1);
                        dy = s.pos(2) - p.position(2);
                        if hypot(dx,dy) < s.radius + 0.3  % 0.3 is player's collision “radius”
                            s.onCollidePlayer(p);
                            % disp("Collision");
                        end
                    end
                end
            end
        end
        function handleHitscanShot(obj, shooterId)
            % Get the shooter’s position & angle
            idx = find([obj.players.id] == shooterId, 1);
            if isempty(idx)
                return
            end
            p    = obj.players(idx);
            orig = p.position(1:2);
            ang  = p.angle;
            % Perform the DDA march cell‐by‐cell (see earlier example)
            hitInfo = obj.raycast(orig, ang, p.position(3));
            % Print hit information on each shot
            disp(hitInfo);
            % Dispatch damage or effects to whichever entity was hit
            if hitInfo.type == "sprite"
                idx = find([obj.spriteManager.sprites.id] == hitInfo.id, 1);
                if isempty(idx)
                    return
                end
                victim = obj.spriteManager.sprites(idx);
                victim.takeDamage(p.firePower);
                if victim.health <= 0
                    obj.spriteManager.removeSprite(hitInfo.id);
                end
            elseif hitInfo.type == "player"
                idx = find([obj.players.id] == hitInfo.id, 1);
                if isempty(idx)
                    return
                end
                victim = obj.players(idx);
                victim.takeDamage(p.firePower);
            end
        end
        function hitInfo = raycast(obj, orig, ang, floorIdx)
            %RAYCAST  DDA raycast: returns first hit as wall, sprite, or player.
            % orig: [x,y], ang: viewing angle in radians, floorIdx: current map layer
            % Starting cell indices
            mapX = floor(orig(1));
            mapY = floor(orig(2));

            % Ray direction vector
            dirX = cos(ang);
            dirY = sin(ang);

            % Avoid division by zero
            if abs(dirX) < eps, dirX = sign(dirX)*eps; end
            if abs(dirY) < eps, dirY = sign(dirY)*eps; end

            % Precompute step sizes
            deltaDistX = abs(1/dirX);
            deltaDistY = abs(1/dirY);

            % Determine step direction and initial side distances
            if dirX < 0
                stepX = -1;
                sideDistX = (orig(1) - mapX) * deltaDistX;
            else
                stepX = 1;
                sideDistX = (mapX + 1 - orig(1)) * deltaDistX;
            end
            if dirY < 0
                stepY = -1;
                sideDistY = (orig(2) - mapY) * deltaDistY;
            else
                stepY = 1;
                sideDistY = (mapY + 1 - orig(2)) * deltaDistY;
            end

            % Prepare return structure
            hitInfo = struct('type',"none",'id',0,'pos',[NaN, NaN]);

            % Perform the DDA loop
            while true
                % Advance to next grid boundary
                if sideDistX < sideDistY
                    sideDistX = sideDistX + deltaDistX;
                    mapX = mapX + stepX;
                else
                    sideDistY = sideDistY + deltaDistY;
                    mapY = mapY + stepY;
                end

                % Compute approximate impact position
                hitPos = [mapX + 0.5, mapY + 0.5];

                % Check player collisions first
                for i = 1:numel(obj.players)
                    p = obj.players(i);
                    if p.position(3) == floorIdx && norm(p.position(1:2) - hitPos) < 0.3
                        hitInfo.type  = "player";
                        hitInfo.id = p.id;
                        hitInfo.pos   = hitPos;
                        return
                    end
                end

                % Check sprite collisions
                for i = 1:numel(obj.spriteManager.sprites)
                    s = obj.spriteManager.sprites(i);
                    if s.pos(3) == floorIdx && norm(s.pos(1:2) - hitPos) < s.radius
                        hitInfo.type  = "sprite";
                        hitInfo.id = s.id;
                        hitInfo.pos   = hitPos;
                        return
                    end
                end

                % Check wall collision (non-free cell)
                if ~obj.mapManager.isCellFree(mapY, mapX, floorIdx)
                    hitInfo.type  = "wall";
                    hitInfo.id = 0;
                    hitInfo.pos   = hitPos;
                    return
                end
            end
        end
        function pushToFlask(obj, serverURL)
            %PUSHTOFLASK  Upload current map/players/sprites to the live-map server.
            %
            %   obj.pushToFlask("http://localhost:5000")      % typical call
            %

            %   serverURL  –  root URL of the Flask server *without* trailing slash

            % ---- 1.  MAP DATA  -------------------------------------------------
            % For a multi-floor game pick whichever slice you want;
            % here we send the floor that player 1 is on, or default to 1.
            if isempty(obj.players)
                floorIdx = 1;
            else
                floorIdx = obj.players(1).position(3);   % player 1’s Z-layer
            end

            % ---- 2.  PLAYER ARRAY  --------------------------------------------
            nP = numel(obj.players);
            % Preallocate for actual positions + one-step waypoints
            dt = 1; % Define dt (timestep) here, or pass as argument if needed
            players = repmat(struct('row',0,'col',0,'mapIdx',1), 1, nP*2);
            for k = 1:nP
                % Extract world coordinates
                x = obj.players(k).position(1);
                y = obj.players(k).position(2);
                f = obj.players(k).position(3);
                % Actual position (zero-based)
                players(k).row    = y - 1;
                players(k).col    = x - 1;
                players(k).mapIdx = f - 1;
                % Compute waypoint offset along facing direction
                ang = obj.players(k).angle;
                dx  = cos(ang) * dt;
                dy  = sin(ang) * dt;
                idx = nP + k;
                players(idx).row    = (y + dy) - 1;
                players(idx).col    = (x + dx) - 1;
                players(idx).mapIdx = f - 1;
            end

            % ---- 3.  SPRITE ARRAY  --------------------------------------------
            nS = numel(obj.spriteManager.sprites);
            sprites = repmat(struct('row',0,'col',0,'mapIdx',1), 1, nS);
            for k = 1:nS
                sprites(k).row = obj.spriteManager.sprites(k).pos(2)-1;
                sprites(k).col = obj.spriteManager.sprites(k).pos(1)-1;
                sprites(k).mapIdx = obj.spriteManager.sprites(k).pos(3)-1;
            end

            % Zero-base positions for JSON payload
            rawChests = obj.mapManager.chests;
            payloadChests = arrayfun(@(c) struct(...
                'position', c.position - [1 1 1], ...
                'isOpen',   c.isOpen, ...
                'hasKey',   c.hasKey), rawChests);

            rawKeys = obj.mapManager.keyManager;
            payloadKeys = arrayfun(@(k) struct(...
                'keyPosition', k.keyPosition - [1 1 1], ...
                'isHeld',      k.isHeld), rawKeys);

            payload = struct( ...
                'players', {players}, ...
                'sprites', {sprites}, ...
                'keys',    {payloadKeys}, ...
                'chests',  {payloadChests} ...
                );
            try
                webwrite(serverURL + "/update", payload, ...
                    weboptions('MediaType','application/json', 'Timeout',5));
            catch ME
                warning("pushToFlask:failed", ...
                    "Could not POST to %s/update — %s", serverURL, ME.message);
                disp(payload);
            end
        end

        function updateLeaderboard(obj,port)
        end

        function payload = getPlayers(obj)
            %GETPLAYERS  Build a struct mapping player IDs to their state
            %   for the raycaster-3 TCP JSON protocol.
            payload = struct();
            for i = 1:numel(obj.players)
                p = obj.players(i);
                % Field name must be a valid MATLAB field: use the numeric ID as string
                idField = num2str(p.id);

                % Match the server’s expected keys:
                state = struct( ...
                    'x',           p.position(1), ...    % world X
                    'y',           p.position(2), ...    % world Y
                    'z',           p.position(3), ...    % floor index
                    'angle',       p.angle,       ...    % facing direction (rad)
                    'health',      p.health,      ...    % current health
                    'is_shooting', false,         ...    % (you can hook in a flag later)
                    'is_dead',     p.isDead,      ...    % death state
                    'is_running',  false               ...% (you can derive from input)
                    );

                payload.(idField) = state;
            end
        end
        function payload = getSprites(obj)
            %CREATESPRITES Build a struct mapping sprite IDs to their state for Python server
            spritesList = obj.spriteManager.sprites;
            payload = struct();  % Initialize empty struct for dictionary

            for i = 1:numel(spritesList)
                s = spritesList(i);
                % Use the sprite's numeric ID for the field name
                idField = sprintf('sprite_%d', s.id);

                % Build state struct matching raycaster-3 expectations
                state = struct( ...
                    'id',            idField, ...
                    'x',             s.pos(1), ...
                    'y',             s.pos(2), ...
                    'z',             s.pos(3), ...
                    'texture_name',  s.type, ...
                    'texture_index', s.animFrame, ...
                    'scale',         s.opacity, ...
                    'health',        s.health, ...
                    'is_shooting',   false, ...
                    'is_dead',       (s.health <= 0) ...
                    );

                % Assign into payload dictionary
                payload.(idField) = state;
            end
        end
        function payload = getEntities(obj)
            %GETENTITIES Build a struct mapping entity IDs to their state for Python server
            payload = struct();

            % --- Chests ---
            chests = obj.mapManager.chests;
            for i = 1:numel(chests)
                chest = chests(i);
                idField = sprintf('entity_chest_%d', i);
                state = struct( ...
                    'id',            idField, ...
                    'x',             chest.position(1), ...
                    'y',             chest.position(2), ...
                    'z',             chest.position(3), ...
                    'type',          'Chest', ...
                    'texture_name',  'Chest', ...
                    'texture_index', 0, ...
                    'is_active',     ~chest.isOpen, ...
                    'scale',         config.SPRITE_SCALE * 0.8 ...
                    );
                payload.(idField) = state;
            end

            % --- Keys ---
            keys = obj.mapManager.keyManager;
            for j = 1:numel(keys)
                key = keys(j);
                idField = sprintf('entity_key_%d', j);
                state = struct( ...
                    'id',            idField, ...
                    'x',             key.keyPosition(1), ...
                    'y',             key.keyPosition(2), ...
                    'z',             key.keyPosition(3), ...
                    'type',          'Key', ...
                    'texture_name',  'Key', ...
                    'texture_index', 0, ...
                    'is_active',     ~key.isHeld, ...
                    'scale',         config.SPRITE_SCALE * 0.5 ...
                    );
                payload.(idField) = state;
            end
            % --- Elevators ---
            elevators = obj.mapManager.elevators;  % Use plural property
            for j = 1:numel(elevators)
                ev = elevators(j);
                idField = sprintf('entity_elevator_%d', j);
                state = struct( ...
                    'id',            idField, ...
                    'x',             ev(1), ...
                    'y',             ev(2), ...
                    'z',             ev(3), ...
                    'type',          'Elevator', ...
                    'texture_name',  'Elevator', ...
                    'texture_index', 0, ...
                    'is_active',     true, ...            % Elevators are always active
                    'scale',         config.SPRITE_SCALE ... % Use default sprite scale
                    );
                payload.(idField) = state;
            end
        end
        function sendUpdatetoServer(obj)
            %SYNCWITHSERVER  Send full game state and process incoming updates

            playersPayload = obj.getPlayers();
            spritesPayload = obj.getSprites();
            entityPayload = obj.getEntities();
            % Build and send game_state_update with properly named fields
            msgStruct = struct( ...
                'type', 'game_state_full', ...
                'payload', struct( ...
                'players', playersPayload, ...
                'sprites', spritesPayload, ...
                'entities', entityPayload ...
                ) ...
                );
            jsonStr = jsonencode(msgStruct);
            % Send JSON + newline to the Python server
            writeline(obj.serverClient, jsonStr);
        end
        function syncWithServer(obj)
            %SYNCWITHSERVER  Sync communication with matlab

            % Now read *all* incoming lines and dispatch by type
            while obj.serverClient.NumBytesAvailable > 0
                raw  = readline(obj.serverClient);
                msg  = jsondecode(char(raw));

                % disp(msg);
                switch msg.type
                    case 'player_joined'
                        % A new client just connected to the Python server
                        newId = msg.payload.client_id;
                        disp("Here is the New Id:");
                        disp(newId);
                        jid = msg.payload.joystick_id;
                        % supply whatever port your joystick service runs on
                        defaultPort = 5100;
                        obj.addPlayer(newId, jid, defaultPort);
                        fprintf('Player %s joined using joystick %d\n', newId, jid);
                        % …any other types you care about…
                end
            end
        end


    end

end


