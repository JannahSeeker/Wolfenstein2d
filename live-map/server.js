import express   from "express";
import http      from "http";
import { Server } from "socket.io";

const app  = express();
const httpServer = http.createServer(app);
const io   = new Server(httpServer, {  // ← WebSocket transport to browsers
  cors: { origin: "*" }                // dev-only CORS                           [oai_citation:0‡Socket.IO](https://socket.io/docs/v3/handling-cors/?utm_source=chatgpt.com)
});

app.use(express.json());               // parses JSON bodies            [oai_citation:1‡Stack Overflow](https://stackoverflow.com/questions/10005939/how-do-i-consume-the-json-post-data-in-an-express-application?utm_source=chatgpt.com)

let worldState = { players: [], sprites: [] };

/* ---- 1A. Receive POSTs from *any* client ---- */
app.post("/update", (req, res) => {
  worldState = req.body;          // { players:[{row,col}], sprites:[...] }
  io.emit("state", worldState);   // broadcast to every browser tab
  res.sendStatus(200);
});

/* ---- 1B. Allow browsers to pull latest state on first load ---- */
app.get("/state", (_, res) => res.json(worldState));

httpServer.listen(3000, () =>
  console.log("⇢ Live-map server on http://localhost:5555"));