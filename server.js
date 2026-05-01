const http = require("http");
const next = require("next");

const dev = false;
const port = process.env.PORT; // använd ENDAST IIS port
const app = next({ dev, dir: __dirname });
const handle = app.getRequestHandler();

app.prepare().then(() => {
  http.createServer((req, res) => {
    // Log unexpected errors
    try {
      handle(req, res);
    } catch (err) {
      console.error('Error handling request:', err);
      res.statusCode = 500;
      res.end('Internal Server Error');
    }
  }).listen(port, (err) => {
    if (err) throw err;
    console.log("Running on port " + port);
  });
});

