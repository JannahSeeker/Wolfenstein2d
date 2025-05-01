classdef Sprite < handle
    %SPRITE  Represents an entity that can move and chase the player.

    properties
        id int32 
        pos        (1,3) double    % [x, y, floor]
        speed      double           % cells per second
        health     double
        maxHealth  double
        opacity    double
        type       string
        state      string
        animFrame  int32
        aiBrain    string           % e.g. 'DirectChaser'
        damage double = 1
        radius  double = 0.4    % collision radius (in world units)
        jitter    double = 0.5    % max random offset per axis
        manager SpriteManager
        path    
        lastTarget
    end

    methods
        function obj = Sprite(pos, type, state, animFrame, aiBrain)
            %SPRITE  Constructor
            obj.pos       = pos;
            obj.type      = type;
            obj.state     = state;
            obj.animFrame = int32(animFrame);
            obj.aiBrain   = aiBrain;
            % Default attributes by AI type
            switch aiBrain
                case 'DirectChaser'
                    obj.speed     = 10.0;
                    obj.health    = 10;
                    obj.maxHealth = 10;
                    obj.opacity   = 1.0;
                otherwise
                    obj.speed     = 0.5;
                    obj.health    = 5;
                    obj.maxHealth = 5;
                    obj.opacity   = 0.5;
            end
            %add switch statement to discern ghost and soldier attributes
        end

        function update(obj, players, mapMgr, dt)
            %UPDATE  Called each frame with an array of Player objects
            switch obj.aiBrain
                case 'DirectChaser'
                    obj.chaseClosestPlayer(players, mapMgr, dt);
                    % add other AI types here...
                case 'SmartChaser'
                    % 1) pick nearest player
                    dists = arrayfun(@(p) norm(p.position(1:2)-obj.pos(1:2)), players);
                    [~, idx] = min(dists);
                    % Compute a point 0.5 blocks ahead of the player in their facing direction
                    dirVec = [cos(players(idx).angle), sin(players(idx).angle)];
                    targetCell = floor(players(idx).position(1:2) + 0.5 * dirVec);

                    % 2) replan if needed
                    if isempty(obj.path) || any(obj.lastTarget ~= targetCell)
                        obj.path       = obj.planPathGrid(targetCell, mapMgr);
                        obj.lastTarget = targetCell;
                    end

                    % 3) move along the planned path
                    obj.followPath(dt, mapMgr);
                case 'Swarmer'
            end
            % Advance animation frame
            obj.animFrame = mod(obj.animFrame + 1, 60);
        end

        function onCollidePlayer(obj, player)
            player.takeDamage(obj.damage);
            % maybe bounce back, play sound, change obj.state, etc.
        end

        function chasePlayer(obj, targetPos, mapMgr, dt)
            %CHASEPLAYER  Move directly toward the player, with collision.
            % apply a small random jitter so sprites don’t cluster perfectly
            offset = (rand(1,2) - 0.5) * obj.jitter;
            targetPos(1:2) = targetPos(1:2) + offset;
            dir = targetPos(1:2) - obj.pos(1:2);
            d   = norm(dir);
            if d < obj.radius, return; end
            dir = dir / d;  % unit direction vector

            % compute proposed step
            dx = dir(1) * obj.speed * dt;
            dy = dir(2) * obj.speed * dt;

            % attempt X move
            newX = obj.pos(1) + dx;
            r    = floor(obj.pos(2));
            c    = floor(newX);
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(1) = newX;
            end

            % attempt Y move
            newY = obj.pos(2) + dy;
            r    = floor(newY);
            c    = floor(obj.pos(1));
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(2) = newY;
            end
        end
        function chaseClosestPlayer(obj, players, mapMgr, dt)
            % Compute distances to each player
            n = numel(players);
            dists = zeros(1,n);
            for i = 1:n
                delta = players(i).position(1:2) - obj.pos(1:2);
                dists(i) = norm(delta);
            end
            % Find the nearest player
            [~, idx] = min(dists);
            % Compute a point 0.5 blocks ahead of the chosen player in their facing direction
            dirVec = [cos(players(idx).angle), sin(players(idx).angle)];
            targetPos = [players(idx).position(1:2) + 0.5 * dirVec, players(idx).position(3)];

            % Now do the usual direct‐chase logic toward targetPos
            dir = targetPos(1:2) - obj.pos(1:2);
            if norm(dir) < eps
                return;
            end
            dir = dir / norm(dir);

            % Step proposal
            dx = dir(1) * obj.speed * dt;
            dy = dir(2) * obj.speed * dt;

            % X‐axis move with collision
            newX = obj.pos(1) + dx;
            r    = floor(obj.pos(2));
            c    = floor(newX);
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(1) = newX;
            end

            % Y‐axis move with collision
            newY = obj.pos(2) + dy;
            r    = floor(newY);
            c    = floor(obj.pos(1));
            if mapMgr.isCellFree(r, c, obj.pos(3))
                obj.pos(2) = newY;
            end
        end

        function takeDamage(obj, amount)
            obj.health = obj.health - amount;
            % disp(obj.health);
            if obj.health <= 0
                obj.onDeath();
            end
        end
        function onDeath(obj)
            % Play death animation, drop loot, award score, etc.
            obj.manager.removeSprite(obj.id);
        end
        function waypoints = planPathGrid(obj, player, mapMgr)
            % plan a shortest path on the tile grid using A* → goalCell
            % Only pathfind if on same floor
            if player.pos(3) ~= obj.pos(3)
                waypoints = zeros(0,2);
                return;
            end
            startCell = floor(obj.pos(1:2));           % [x,y] → [col,row]
            goalCell  = floor(player.pos(1:2));
            grid      = mapMgr.map(:,:,obj.pos(3));    % occupancy
            [nRows,nCols] = size(grid);

            % A* bookkeeping
            gScore = inf(nRows,nCols);
            fScore = inf(nRows,nCols);
            cameFrom = zeros(nRows,nCols,2);

            sr = startCell(2); sc = startCell(1);
            gr = goalCell(2); gc = goalCell(1);
            gScore(sr,sc) = 0;
            fScore(sr,sc) = abs(sr-gr) + abs(sc-gc);

            openSet = false(nRows,nCols);
            openSet(sr,sc) = true;

            dirs = [ -1 0; 1 0; 0 -1; 0 1 ];
            % Main A* loop
            while any(openSet,'all')
                % pick node in openSet with lowest fScore
                temp = fScore;
                temp(~openSet) = inf;
                [~, idx] = min(temp(:));
                [r, c] = ind2sub(size(fScore), idx);
                if r==gr && c==gc
                    break;
                end
                openSet(r,c) = false;
                for d = 1:4
                    nr = r + dirs(d,1);
                    nc = c + dirs(d,2);
                    if nr<1||nr>nRows||nc<1||nc>nCols || grid(nr,nc)~=0
                        continue;
                    end
                    tentativeG = gScore(r,c) + 1;
                    if tentativeG < gScore(nr,nc)
                        cameFrom(nr,nc,:) = [r,c];
                        gScore(nr,nc) = tentativeG;
                        h = abs(nr-gr) + abs(nc-gc);
                        fScore(nr,nc) = tentativeG + h;
                        openSet(nr,nc) = true;
                    end
                end
            end

            % Reconstruct path
            waypoints = zeros(0,2);
            if isfinite(gScore(gr,gc))
                curR = gr; curC = gc;
                while ~(curR==sr && curC==sc)
                    waypoints = [[curC,curR]; waypoints];
                    prev = squeeze(cameFrom(curR,curC,:))';
                    curR = prev(1); curC = prev(2);
                end
            end
        end
        function followPath(obj, dt, mapMgr)
            if isempty(obj.path), return; end
            nextWP = obj.path(1,:);               % [x,y] next cell center
            dir    = nextWP - obj.pos(1:2);
            dist   = norm(dir);
            if dist < 0.1
                % reached that waypoint → pop it
                obj.path(1,:) = [];
            else
                dir = dir / dist;
                dx  = dir(1) * obj.speed * dt;
                dy  = dir(2) * obj.speed * dt;
                obj.move(dx, dy, mapMgr);         % reuse your collision‐safe move
            end
        end



    end

end