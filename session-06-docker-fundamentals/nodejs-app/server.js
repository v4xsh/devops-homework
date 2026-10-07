const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.send("<h1>Hello World from Node.js (Express) in Docker - Vansh Dobhal (Roll No. 10099)</h1>\n");
});

app.get("/health", (req, res) => res.json({ status: "ok" }));

app.listen(PORT, () => {
  console.log(`Node.js app listening on port ${PORT}`);
});
