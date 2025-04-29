/***** Live grid viewer  *******************************************/
const GRID_ROWS = 16, GRID_COLS = 16, CELL = 35;

let mapData = Array(GRID_ROWS).fill().map(()=>Array(GRID_COLS).fill(0));
let players = [], sprites = [];

function setup() {
  createCanvas(GRID_COLS * CELL, GRID_ROWS * CELL);
  noLoop();                        // redraw only when data changes

  // 1st snapshot so canvas isn't blank
  httpGet("/state", "json", applyState);

  // WebSocket live updates
  const socket = io();             // same origin
  socket.on("state", applyState);
}

function draw() {
  background(255);
  stroke(200);
  // grid
  for (let r=0; r<GRID_ROWS; r++)
    for (let c=0; c<GRID_COLS; c++) {
      fill(mapData[r][c] ? 0 : 255);
      rect(c*CELL, r*CELL, CELL, CELL);
    }
  // sprites
  fill(0);
  noStroke();
  sprites.forEach(s => diamond(s.col, s.row));
  // players
  fill(255,0,0);
  stroke(80);
  players.forEach(p => ellipse(p.col*CELL, p.row*CELL, CELL*0.6));
}

function applyState(s) {
  players = s.players ?? players;
  sprites = s.sprites ?? sprites;
  redraw();
}
function diamond(cx, cy) {
  cx*=CELL; cy*=CELL;
  quad(cx,cy-CELL*0.3, cx+CELL*0.3,cy, cx,cy+CELL*0.3, cx-CELL*0.3,cy);
}