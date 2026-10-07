const express = require("express");
const os = require("os");

const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.send(`<h1>Hello World from Node.js - Session 7 - Vansh Dobhal (10099)</h1><p>container: ${os.hostname()}</p>\n`);
});

app.listen(PORT, () => console.log(`node app listening on ${PORT}`));
