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
    end

    methods
        function obj = GameState()
            % Construct all sub‐objects
            obj.mapManager    = MapManager(obj);
            obj.spriteManager = SpriteManager(obj);
            obj.leaderboard = struct('name', {}, 'time', {});  % start empty

        end

        function addPlayer(obj, id, port)
            % Dynamically add another player at runtime
            p = Player(obj);
            p.id = id;
            p.bindJoystick(id, port);
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
        end
        function updateSprites(obj, dt)
            % Advance all sprite AIs
            for s = obj.spriteManager.sprites
                s.update(obj.players(1), obj.mapManager, dt);
                % If you want sprites to see all players, you could pass the
                % entire players array instead of just one.
            end
        end

        function playerWin(obj, id)
            %PLAYERWIN  Record a finishing player into the leaderboard and sort by time
            p = obj.players(id);
            % Assume each Player has .name and .finishTime properties:
            entry.name = p.name;
            entry.time = p.time;
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
            p = obj.players(id);
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
                        end
                    end
                end
            end
        end
        function handleHitscanShot(obj, shooterId)
            % Get the shooter’s position & angle
            p    = obj.players(shooterId);
            orig = p.position(1:2);
            ang  = p.angle;
            % Perform the DDA march cell‐by‐cell (see earlier example)
            hitInfo = obj.raycast(orig, ang, p.position(3));
            % Dispatch damage or effects to whichever entity was hit
            if hitInfo.type == "sprite"
                victim = obj.spriteManager.sprites(hitInfo.index);
                victim.takeDamage(p.firePower, shooterId);
                if victim.health <= 0
                    obj.spriteManager.removeSprite(hitInfo.index);
                end
            elseif hitInfo.type == "player"
                victim = obj.players(hitInfo.index);
                victim.takeDamage(p.firePower);
            end
        end
        function hitInfo = raycast(obj, orig, ang, floor)
            %RAYCAST  DDA raycast: returns first hit as wall, sprite, or player.
            % orig: [x,y], ang: viewing angle in radians, floor: current map layer

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
            hitInfo = struct('type',"none",'index',0,'pos',[NaN, NaN]);

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
                    if p.position(3) == floor && ...
                            norm(p.position(1:2) - hitPos) < 0.3
                        hitInfo.type  = "player";
                        hitInfo.index = i;
                        hitInfo.pos   = hitPos;
                        return
                    end
                end

                % Check sprite collisions
                for i = 1:numel(obj.spriteManager.sprites)
                    s = obj.spriteManager.sprites(i);
                    if s.pos(3) == floor && ...
                            norm(s.pos(1:2) - hitPos) < s.radius
                        hitInfo.type  = "sprite";
                        hitInfo.index = i;
                        hitInfo.pos   = hitPos;
                        return
                    end
                end

                % Check wall collision (non-free cell)
                if ~obj.mapManager.isCellFree(mapY, mapX, floor)
                    hitInfo.type  = "wall";
                    hitInfo.index = 0;
                    hitInfo.pos   = hitPos;
                    return
                end
            end
        end
    end
end