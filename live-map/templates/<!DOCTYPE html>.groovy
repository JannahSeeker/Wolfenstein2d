<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Live Map</title>

    <!-- p5.js -->
    <script src="https://cdn.jsdelivr.net/npm/p5@1.9.1/lib/p5.min.js"></script>

    <!-- Socket.IO client (CDN) -->
    <script src="https://cdn.socket.io/4.7.5/socket.io.min.js"></script>

    <style>
      html,
      body {
        margin: 0;
        display: flex;
        justify-content: center;
      }
    </style>
  </head>
  <body>
    <!-- p5 injects <canvas> here -->

    <script>
      /* ────────────────────────── Globals ───────────────────────── */
      let maps = [] // filled by /state
      let players = []
      let sprites = []
      let drawn = 0
      const CELL = 35 // px per tile
      const apiBase = 'http://localhost:5555'
      // Palette for sprite colors
      const spriteColors = [
        [255, 0, 0], // red
        [0, 255, 0], // green
        [0, 0, 255], // blue
        [255, 255, 0] // yellow
      ]

      /* ───────────── Socket.IO connect + first snapshot ─────────── */
      const socket = io(apiBase)
      socket.on('connect', () => console.log('✅ socket', socket.id))
      socket.on('state', applyState)

      fetch(apiBase + '/state')
        .then(r => r.json())
        .then(applyState)
        .catch(e => console.error('failed /state', e))

      /* ─────────────────────── p5 lifecycle ─────────────────────── */
      function setup() {
          resizeCanvas(16 * CELL * 3, 16 * CELL)

        mapLayer = createGraphics(width, height)
        dynamicLayer = createGraphics(width, height)

        image(mapLayer, 0, 0)
        image(dynamicLayer, 0, 0)
        noLoop()
      }
      function drawMap(gfx) {

        gfx.stroke(200)
        maps.forEach((mapData, mapIdx) => {
          const xOffset = mapIdx * mapData[0].length * CELL
          for (let r = 0; r < mapData.length; r++) {
            for (let c = 0; c < mapData[r].length; c++) {
              // choose color based on tile code
              const code = mapData[r][c]
              if (code === 0) {
                gfx.fill(255) // empty => white
              } else if (code === 1) {
                gfx.fill(0) // wall  => black
              } else if (code === 2) {
                fill(200, 200, 0) // special tile type 2 => yellowish
              } else if (code === 3) {
                gfx.fill(0, 200, 200) // type 3 => cyan
              } else if (code === 8) {
                gfx.fill(150, 0, 150) // elevator (8) => purple
              } else {
                gfx.fill(150) // fallback grey
              }
              gfx.rect(xOffset + c * CELL, r * CELL, CELL, CELL)
            }
          }
        })
        drawn = 1
      }

      function updateDynamic() {
        // background(255)
        dynamicLayer.clear()
        dynamicLayer.noStroke()

        sprites.forEach((s, i) => {
          const [r, g, b] = spriteColors[i % spriteColors.length]
          dynamicLayer.fill(r, g, b)
          // assume each sprite has a `mapIdx` property telling you which map
          const xOff = s.mapIdx * maps[0][0].length * CELL
          diamond(xOff + s.col * CELL, s.row * CELL)
        })
        // players
        dynamicLayer.stroke(80)
        dynamicLayer.fill(45, 3, 0)
        if (Array.isArray(players)) {
          players.forEach((p, i) => {
            // pick a color by index, wrap if needed
            const [r, g, b] = spriteColors[i % spriteColors.length]
            const xOff = p.mapIdx * maps[0][0].length * CELL
            fill(r, g, b)
            squareCentered(xOff + p.col * CELL, p.row * CELL, CELL * 0.2)
          })
        } else if (players && typeof players === 'object') {
          // single-player case
          const [r, g, b] = spriteColors[0]
          const xOff = players.mapIdx * maps[0][0].length * CELL
          dynamicLayer.fill(r, g, b)
          squareCentered(
            xOff + players.col * CELL,
            players.row * CELL,
            CELL * 0.2
          )
        }
        // players.forEach(p => ellipse(p.col * CELL, p.row * CELL, CELL * 0.6))
        image(mapLayer, 0, 0)
        image(dynamicLayer, 0, 0)
      }

      /* ───────────────────────── Helpers ────────────────────────── */
      function applyState(s) {
        print(s)
        if (s.map && !drawn) {
          const raw = s.map // raw[row][col][floor]
          const rows = raw.length // H
          const cols = raw[0].length // W
          const floors = raw[0][0].length
          // width = number of columns in one map; height = rows in one map
          maps = [] // will become an array of F 2D grids
          for (let f = 0; f < floors; f++) {
            const floorMap = []
            for (let r = 0; r < rows; r++) {
              const rowArr = []
              for (let c = 0; c < cols; c++) {
                rowArr.push(raw[r][c][f]) // extract the value for floor f
              }
              floorMap.push(rowArr)
            }
            maps.push(floorMap)
          }
          resizeCanvas(cols * CELL * floors, rows * CELL)
          drawMap(mapLayer)
        }
        if (s.players) players = s.players
        if (s.sprites) sprites = s.sprites

        updateDynamic()
      }
      // Draw a centered diamond of “radius” d around (x,y)
      function diamond(x, y, d = CELL * 0.3) {
        dynamicLayer.quad(x, y - d, x + d, y, x, y + d, x - d, y)
      }

      // Draw a centered square of side length s around (x,y)
      function squareCentered(x, y, s) {
        dynamicLayer.rect(x - s / 2, y - s / 2, s, s)
      }

      // Draw a centered circle of radius r around (x,y)
      function circleCentered(x, y, r) {
        ellipse(x, y, r * 2, r * 2)
      }

      // Draw a triangle given its three vertices
      function triangleAt(x1, y1, x2, y2, x3, y3) {
        triangle(x1, y1, x2, y2, x3, y3)
      }

      // Draw a regular n-gon (e.g. pentagon, hexagon) of radius r centered at x,y
      function polygon(x, y, r, n) {
        beginShape()
        for (let i = 0; i < n; i++) {
          const theta = (TWO_PI * i) / n - HALF_PI // start at top
          vertex(x + r * cos(theta), y + r * sin(theta))
        }
        endShape(CLOSE)
      }
    </script>
  </body>
</html>
