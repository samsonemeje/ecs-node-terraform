const express = require("express");

const app = express();

const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.json({
    message: "Successfully containerized and ready to serve. I’m like a genie, but instead of three wishes, I give you 200 OKs."
  });
});

app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});


// process.on("SIGTERM", () => {
//   console.log("SIGTERM received. Shutting down gracefully...");
//   server.close(() => {
//     process.exit(0);
//   });
// });
