const express = require("express");
const mongoose = require("mongoose");
const jwt = require("jsonwebtoken");
const multer = require("multer");
const path = require("path");
const cors = require("cors");
const http = require("http");
const { Server } = require("socket.io");
const Sentiment = require("sentiment");
const axios = require('axios');
require("dotenv").config();

const sentimentAnalyzer = new Sentiment();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
  },
});

const port = process.env.PORT || 5000;

// Middleware
app.use(express.json());
app.use(cors());

// MongoDB Connection
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('✅ Connected to MongoDB'))
  .catch(err => console.error('❌ MongoDB connection error:', err));

mongoose.connection.on('error', err => {
  console.error('❌ MongoDB error:', err);
});

// Static file for profile images
const storage = multer.diskStorage({
  destination: "./upload/images",
  filename: (req, file, cb) => {
    return cb(null, `${file.fieldname}_${Date.now()}${path.extname(file.originalname)}`);
  },
});
const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext !== ".jpg" && ext !== ".jpeg" && ext !== ".png") {
      return cb(new Error("Only images are allowed"));
    }
    cb(null, true);
  },
});
app.use("/images", express.static("upload/images"));

// Models
const User = mongoose.model("Users", {
  name: String,
  email: { type: String, unique: true },
  password: String,
  profileImage: String,
  date: { type: Date, default: Date.now },
});

const Conversation = mongoose.model("Conversation", {
  participants: [String], // user IDs
});

const Message = mongoose.model("Message", {
  conversationId: String,
  senderId: String,
  text: String,
  sentiment: String, // <-- New field
  timestamp: { type: Date, default: Date.now },
});

// Auth APIs
app.post("/signup", upload.single("profileImage"), async (req, res) => {
  const existing = await User.findOne({ email: req.body.email });
  if (existing) return res.status(400).json({ success: false, error: "User already exists" });

  const user = new User({
    name: req.body.username,
    email: req.body.email,
    password: req.body.password,
    profileImage: req.file ? `/images/${req.file.filename}` : null,
  });

  await user.save();
  const token = jwt.sign({ user: { id: user.id } }, process.env.JWT_SECRET);
  res.json({ success: true, token });
});

app.post("/login", async (req, res) => {
  const user = await User.findOne({ email: req.body.email });
  if (!user || user.password !== req.body.password)
    return res.status(401).json({ success: false, error: "Invalid credentials" });

  const token = jwt.sign({ user: { id: user.id } }, process.env.JWT_SECRET);
  res.json({ success: true, token });
});

const fetchUser = (req, res, next) => {
  const token = req.header("auth-token");
  if (!token) return res.status(401).json({ error: "Access denied" });

  try {
    const data = jwt.verify(token, process.env.JWT_SECRET);
    req.user = data.user;
    next();
  } catch {
    res.status(401).json({ error: "Invalid token" });
  }
};

// Get all users
app.get("/users", fetchUser, async (req, res) => {
  const users = await User.find({ _id: { $ne: req.user.id } });
  res.json(users);
});

// Conversation & Messaging APIs
app.get("/conversations", fetchUser, async (req, res) => {
  const conversations = await Conversation.find({ participants: req.user.id });
  res.json(conversations);
});

app.get("/messages/:conversationId", fetchUser, async (req, res) => {
  const messages = await Message.find({ conversationId: req.params.conversationId });
  res.json(messages);
});

app.post("/conversations", fetchUser, async (req, res) => {
  const { participantId } = req.body;

  let conversation = await Conversation.findOne({
    participants: { $all: [req.user.id, participantId] },
  });

  if (!conversation) {
    conversation = new Conversation({ participants: [req.user.id, participantId] });
    await conversation.save();
  }

  res.json(conversation);
});

// Optional: Get sentiment distribution for a conversation
app.get("/sentiment/:conversationId", fetchUser, async (req, res) => {
  const messages = await Message.find({ conversationId: req.params.conversationId });
  const sentimentCounts = { Positive: 0, Negative: 0, Neutral: 0 };

  messages.forEach(msg => {
    sentimentCounts[msg.sentiment] = (sentimentCounts[msg.sentiment] || 0) + 1;
  });

  res.json(sentimentCounts);
});

// Get all messages sent by a specific user
app.get("/messages/user/:userId", fetchUser, async (req, res) => {
  try {
    console.log("🔍 Fetching messages for user:", req.params.userId);
    console.log("🔑 Auth token:", req.header("auth-token"));
    
    const messages = await Message.find({ senderId: req.params.userId });
    console.log("📝 Total messages found:", messages.length);
    
    if (messages.length === 0) {
      console.log("ℹ️ No messages found for user");
      // Check if user exists
      const user = await User.findById(req.params.userId);
      console.log("👤 User exists:", !!user);
    } else {
      console.log("📊 First message sample:", JSON.stringify(messages[0], null, 2));
    }
    
    res.json(messages);
  } catch (err) {
    console.error("❌ Error fetching messages:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// DELETE message
app.delete("/messages/:messageId", fetchUser, async (req, res) => {
  try {
    const message = await Message.findById(req.params.messageId);
    if (!message) return res.status(404).json({ message: "Message not found" });

    if (message.senderId !== req.user.id)
      return res.status(403).json({ message: "Unauthorized" });

    await message.deleteOne();

    io.to(message.conversationId).emit("messageDeleted", { messageId: message._id });

    res.json({ message: "Deleted successfully" });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

// Socket.io Chat
const onlineUsers = new Map(); // Track online users by their userId

io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) return next(new Error("Authentication error"));

  try {
    const data = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = data.user.id;
    next();
  } catch {
    next(new Error("Authentication error"));
  }
});

io.on("connection", (socket) => {
  console.log("User connected:", socket.userId);

  // Add user to online users map
  onlineUsers.set(socket.userId, socket.id);

  // Notify all users about the new online user
  socket.broadcast.emit("userOnline", socket.userId);

  // Join the conversation room
  socket.on("join", (conversationId) => {
    socket.join(conversationId);
  });

  // Message event (with sentiment analysis logic)
  socket.on("message", async ({ conversationId, text }) => {
    const sentimentResult = sentimentAnalyzer.analyze(text);
    let sentiment =
      sentimentResult.score > 0 ? "Positive" :
      sentimentResult.score < 0 ? "Negative" : "Neutral";

    try {
      const prompt =`You are a sentiment analysis model. Analyze the sentiment of the following message written in Hinglish (a mix of Hindi and English used in informal conversation). 

        Classify the sentiment strictly as one of the following (case sensitive):
        - Positive
        - Negative
        - Neutral
        
        Examples:
        1. "Yeh movie toh kamaal ki thi!" → Positive  
        2. "Mujhe bilkul pasand nahi aaya." → Negative  
        3. "Theek hai, chal sakta hai." → Neutral  
        4. "Kya bakwaas service thi yaar!" → Negative  
        5. "Mast laga yeh experience." → Positive  
        
        Now classify this sentence: "${text}"
        
        Sentiment:`; 
      const geminiResponse = await axios.post(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
        {
          contents: [{ parts: [{ text: prompt }] }],
        },
        {
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": process.env.GEMINI_API_KEY,
          },
        }
      );
  
      const modelReply = geminiResponse.data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
      const cleaned = modelReply.toLowerCase();
  
      if (cleaned.includes("positive")) sentiment = "Positive";
      else if (cleaned.includes("negative")) sentiment = "Negative";
      else if (cleaned.includes("neutral")) sentiment = "Neutral";
  
    } catch (error) {
      console.error("⚠️ Gemini API fallback failed:", error.message);
    }

    const message = new Message({
      conversationId,
      senderId: socket.userId,
      text,
      sentiment,
    });

    await message.save();
    io.to(conversationId).emit("message", message);
  });

  // Listen for user disconnect event
  socket.on("disconnect", () => {
    console.log("User disconnected:", socket.userId);

    // Remove user from the online users map
    onlineUsers.delete(socket.userId);

    // Notify other users that this user is offline
    socket.broadcast.emit("userOffline", socket.userId);
  });
});

// Start Server
server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
