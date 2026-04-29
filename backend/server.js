import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import axios from "axios";
import cron from "node-cron";
import multer from "multer";
import fs from "fs";
import path from "path";
import { randomUUID } from "crypto";
import { fileURLToPath } from "url";
import { GoogleGenerativeAI } from "@google/generative-ai";

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

const PORT = process.env.PORT || 3000;
const GRAPH_VERSION = process.env.GRAPH_VERSION || "v19.0";

const META_ACCESS_TOKEN = process.env.META_ACCESS_TOKEN;
const IG_USER_ID = process.env.IG_USER_ID;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const uploadsDir = path.join(__dirname, "uploads");

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

app.use("/uploads", express.static(uploadsDir));

const upload = multer({
  dest: uploadsDir,
  limits: {
    fileSize: 25 * 1024 * 1024
  }
});

// TEMP in-memory posts. Good for testing only.
// Later replace this with Supabase/PostgreSQL.
const posts = [];
const autoReplyRules = [];
const webhookEvents = [];

app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

function getBaseUrl(req) {
  const protocol = req.headers["x-forwarded-proto"] || req.protocol;
  return `${protocol}://${req.get("host")}`;
}

function requireMetaConfig() {
  if (!META_ACCESS_TOKEN || !IG_USER_ID) {
    throw new Error("Missing META_ACCESS_TOKEN or IG_USER_ID in environment variables.");
  }
}

function requireGeminiConfig() {
  if (!GEMINI_API_KEY) {
    throw new Error("Missing GEMINI_API_KEY in environment variables.");
  }
}

function isPublicUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" || parsed.protocol === "http:";
  } catch {
    return false;
  }
}

function normalizeHashtags(hashtags) {
  if (!hashtags) return [];

  if (Array.isArray(hashtags)) {
    return hashtags
      .map((tag) => String(tag).trim())
      .filter(Boolean)
      .map((tag) => (tag.startsWith("#") ? tag : `#${tag}`));
  }

  if (typeof hashtags === "string") {
    return hashtags
      .split(/[\s,]+/)
      .map((tag) => tag.trim())
      .filter(Boolean)
      .map((tag) => (tag.startsWith("#") ? tag : `#${tag}`));
  }

  return [];
}

function getBodyValue(body, camelKey, snakeKey) {
  return body[camelKey] ?? body[snakeKey];
}

async function publishToInstagram({ imageUrl, caption }) {
  requireMetaConfig();

  if (!imageUrl || !isPublicUrl(imageUrl)) {
    throw new Error("imageUrl must be a public direct URL.");
  }

  const createContainerUrl = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/media`;

  const containerResponse = await axios.post(createContainerUrl, null, {
    params: {
      image_url: imageUrl,
      caption: caption || "",
      access_token: META_ACCESS_TOKEN
    }
  });

  const creationId = containerResponse.data?.id;

  if (!creationId) {
    throw new Error("Meta did not return creation_id.");
  }

  const publishUrl = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/media_publish`;

  const publishResponse = await axios.post(publishUrl, null, {
    params: {
      creation_id: creationId,
      access_token: META_ACCESS_TOKEN
    }
  });

  return {
    creationId,
    publishId: publishResponse.data?.id
  };
}

async function generateWithGemini(prompt, modelName = "gemini-1.5-flash") {
  requireGeminiConfig();

  const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: modelName });

  const result = await model.generateContent(prompt);
  return result.response.text();
}

function parseJsonLoose(text) {
  try {
    return JSON.parse(text.replace(/```json|```/g, "").trim());
  } catch {
    return null;
  }
}

async function generateCaptionWithGemini({
  imageUrl,
  language = "arabic",
  tone = "premium",
  model = "gemini-1.5-flash"
}) {
  const prompt = `
You are a social media marketing assistant for artificial trees, artificial flowers, and luxury decoration products.

Generate Instagram content for this image.

Image URL:
${imageUrl}

Language:
${language}

Tone:
${tone}

Return strict JSON only:
{
  "caption": "short marketing caption",
  "hashtags": ["#tag1", "#tag2", "#tag3", "#tag4", "#tag5", "#tag6", "#tag7", "#tag8"],
  "alt_text": "short alt text"
}
`;

  const text = await generateWithGemini(prompt, model);
  const parsed = parseJsonLoose(text);

  if (parsed) {
    return {
      caption: parsed.caption || "",
      hashtags: normalizeHashtags(parsed.hashtags),
      alt_text: parsed.alt_text || ""
    };
  }

  return {
    caption: text,
    hashtags: [],
    alt_text: ""
  };
}

async function generateEditPromptWithGemini({
  imageUrl,
  editStyle = "luxury interior background",
  language = "english",
  model = "gemini-1.5-flash"
}) {
  const prompt = `
Create a professional AI image editing prompt for a product image.

Image URL:
${imageUrl}

Edit style:
${editStyle}

Language:
${language}

The prompt must be for editing an existing product image, not generating from scratch.

Rules:
- Preserve the main product exactly.
- Keep the artificial tree, flowers, pot, planter, trunk, leaves, branches, shape, size, angle, and proportions exactly the same.
- Change only the background, environment, decoration, lighting, shadows, and composition.
- Make it photorealistic.
- Make it Instagram-ready.
- Default output size: 1080x1350.
- No cartoon, no painting, no AI-looking result.
- No text or watermark.

Return strict JSON only:
{
  "prompt": "full editing prompt here"
}
`;

  const text = await generateWithGemini(prompt, model);
  const parsed = parseJsonLoose(text);

  return {
    prompt: parsed?.prompt || text.replace(/```json|```/g, "").trim()
  };
}

app.get("/", (req, res) => {
  res.json({
    ok: true,
    app: "AutoFlow Backend",
    status: "running"
  });
});

app.get("/api/health", (req, res) => {
  res.json({
    ok: true,
    timestamp: new Date().toISOString()
  });
});

app.get("/api/meta/test-connection", async (req, res) => {
  try {
    requireMetaConfig();

    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}`;
    const response = await axios.get(url, {
      params: {
        fields: "id,username,name",
        access_token: META_ACCESS_TOKEN
      }
    });

    res.json({
      ok: true,
      account: response.data
    });
  } catch (error) {
    console.error("Meta test failed:", error.response?.data || error.message);
    res.status(500).json({
      ok: false,
      error: error.response?.data || error.message
    });
  }
});

app.post("/api/meta/test-connection", async (req, res) => {
  try {
    requireMetaConfig();

    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}`;
    const response = await axios.get(url, {
      params: {
        fields: "id,username,name",
        access_token: META_ACCESS_TOKEN
      }
    });

    res.json({
      ok: true,
      account: response.data
    });
  } catch (error) {
    console.error("Meta test failed:", error.response?.data || error.message);
    res.status(500).json({
      ok: false,
      error: error.response?.data || error.message
    });
  }
});

app.post("/api/meta/publish-now", async (req, res) => {
  try {
    const imageUrl = getBodyValue(req.body, "imageUrl", "image_url");
    const caption = req.body.caption || req.body.final_text || req.body.finalText || "";

    const result = await publishToInstagram({
      imageUrl,
      caption
    });

    res.json({
      ok: true,
      result
    });
  } catch (error) {
    console.error("Publish now failed:", error.response?.data || error.message);
    res.status(500).json({
      ok: false,
      error: error.response?.data || error.message
    });
  }
});

app.post("/api/gemini/test", async (req, res) => {
  try {
    requireGeminiConfig();

    const text = await generateWithGemini(
      "Return strict JSON only: {\"ok\": true, \"message\": \"Gemini connected\"}",
      req.body.model || "gemini-1.5-flash"
    );

    res.json({
      ok: true,
      raw: text,
      result: parseJsonLoose(text) || { message: text }
    });
  } catch (error) {
    console.error("Gemini test failed:", error.message);
    res.status(500).json({
      ok: false,
      error: error.message
    });
  }
});

app.post("/api/gemini/generate-caption", async (req, res) => {
  try {
    const imageUrl = getBodyValue(req.body, "imageUrl", "image_url");
    const language = req.body.language || "arabic";
    const tone = req.body.tone || "premium";
    const model = req.body.model || req.body.selectedModel || "gemini-1.5-flash";

    if (!imageUrl) {
      return res.status(400).json({
        ok: false,
        error: "imageUrl is required."
      });
    }

    const result = await generateCaptionWithGemini({
      imageUrl,
      language,
      tone,
      model
    });

    res.json({
      ok: true,
      result
    });
  } catch (error) {
    console.error("Generate caption failed:", error.message);
    res.status(500).json({
      ok: false,
      error: error.message
    });
  }
});

app.post("/api/gemini/generate-edit-prompt", async (req, res) => {
  try {
    const imageUrl = getBodyValue(req.body, "imageUrl", "image_url");
    const editStyle = req.body.editStyle || req.body.edit_style || "luxury interior background";
    const language = req.body.language || "english";
    const model = req.body.model || req.body.selectedModel || "gemini-1.5-flash";

    if (!imageUrl) {
      return res.status(400).json({
        ok: false,
        error: "imageUrl is required."
      });
    }

    const result = await generateEditPromptWithGemini({
      imageUrl,
      editStyle,
      language,
      model
    });

    res.json({
      ok: true,
      result
    });
  } catch (error) {
    console.error("Generate edit prompt failed:", error.message);
    res.status(500).json({
      ok: false,
      error: error.message
    });
  }
});

app.post("/api/ai/edit-image", async (req, res) => {
  const originalImageUrl =
    getBodyValue(req.body, "originalImageUrl", "original_image_url") ||
    getBodyValue(req.body, "imageUrl", "image_url");

  const prompt = req.body.prompt || req.body.ai_edit_prompt || "";
  const size = req.body.size || "1080x1350";
  const model = req.body.model || "manual_backend_model";

  if (!originalImageUrl) {
    return res.status(400).json({
      ok: false,
      error: "originalImageUrl is required."
    });
  }

  // Real image editing needs an external image-editing provider.
  // This endpoint is intentionally explicit so the Flutter app does not fail silently.
  return res.status(501).json({
    ok: false,
    error:
      "AI image editing provider is not configured yet. Add Replicate/OpenAI/Gemini image editing provider in backend.",
    details: {
      originalImageUrl,
      prompt,
      size,
      model
    }
  });
});

app.post("/api/upload", upload.single("file"), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        ok: false,
        error: "No file uploaded. Use field name: file"
      });
    }

    const ext = path.extname(req.file.originalname || "") || ".jpg";
    const newFileName = `${req.file.filename}${ext}`;
    const oldPath = req.file.path;
    const newPath = path.join(uploadsDir, newFileName);

    fs.renameSync(oldPath, newPath);

    const publicUrl = `${getBaseUrl(req)}/uploads/${newFileName}`;

    res.json({
      ok: true,
      id: req.file.filename,
      filename: newFileName,
      url: publicUrl,
      mediaUrl: publicUrl,
      imageUrl: publicUrl,
      image_url: publicUrl,
      mediaType: "image"
    });
  } catch (error) {
    console.error("Upload failed:", error.message);
    res.status(500).json({
      ok: false,
      error: error.message
    });
  }
});

app.post("/api/posts", (req, res) => {
  const imageUrl = getBodyValue(req.body, "imageUrl", "image_url");
  const caption = req.body.caption || "";
  const hashtags = normalizeHashtags(req.body.hashtags);
  const scheduledAt = getBodyValue(req.body, "scheduledAt", "scheduled_at");

  if (!imageUrl || !scheduledAt) {
    return res.status(400).json({
      ok: false,
      error: "imageUrl and scheduledAt are required."
    });
  }

  const post = {
    id: randomUUID(),
    imageUrl,
    image_url: imageUrl,
    caption,
    hashtags,
    finalText: `${caption}\n${hashtags.join(" ")}`.trim(),
    final_text: `${caption}\n${hashtags.join(" ")}`.trim(),
    scheduledAt,
    scheduled_at: scheduledAt,
    status: "approved",
    publishAttempts: 0,
    publish_attempts: 0,
    metaContainerId: null,
    meta_container_id: null,
    metaPublishId: null,
    meta_publish_id: null,
    errorMessage: null,
    error_message: null,
    createdAt: new Date().toISOString(),
    created_at: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    publishedAt: null,
    published_at: null
  };

  posts.push(post);

  res.json({
    ok: true,
    post
  });
});

app.get("/api/posts", (req, res) => {
  res.json({
    ok: true,
    posts
  });
});

app.post("/api/posts/:id/retry", async (req, res) => {
  const post = posts.find((p) => p.id === req.params.id);

  if (!post) {
    return res.status(404).json({
      ok: false,
      error: "Post not found."
    });
  }

  try {
    post.status = "publishing";
    post.publishAttempts += 1;
    post.publish_attempts = post.publishAttempts;
    post.updatedAt = new Date().toISOString();
    post.updated_at = post.updatedAt;

    const result = await publishToInstagram({
      imageUrl: post.imageUrl,
      caption: post.finalText
    });

    post.status = "published";
    post.metaContainerId = result.creationId;
    post.meta_container_id = result.creationId;
    post.metaPublishId = result.publishId;
    post.meta_publish_id = result.publishId;
    post.publishedAt = new Date().toISOString();
    post.published_at = post.publishedAt;
    post.updatedAt = new Date().toISOString();
    post.updated_at = post.updatedAt;
    post.errorMessage = null;
    post.error_message = null;

    res.json({
      ok: true,
      post
    });
  } catch (error) {
    post.status = "failed";
    post.errorMessage = JSON.stringify(error.response?.data || error.message);
    post.error_message = post.errorMessage;
    post.updatedAt = new Date().toISOString();
    post.updated_at = post.updatedAt;

    res.status(500).json({
      ok: false,
      post
    });
  }
});

cron.schedule("*/5 * * * *", async () => {
  const now = new Date();

  const duePosts = posts.filter((post) => {
    return (
      post.status === "approved" &&
      new Date(post.scheduledAt) <= now &&
      post.publishAttempts < 3
    );
  });

  for (const post of duePosts) {
    try {
      post.status = "publishing";
      post.publishAttempts += 1;
      post.publish_attempts = post.publishAttempts;
      post.updatedAt = new Date().toISOString();
      post.updated_at = post.updatedAt;

      const result = await publishToInstagram({
        imageUrl: post.imageUrl,
        caption: post.finalText
      });

      post.status = "published";
      post.metaContainerId = result.creationId;
      post.meta_container_id = result.creationId;
      post.metaPublishId = result.publishId;
      post.meta_publish_id = result.publishId;
      post.publishedAt = new Date().toISOString();
      post.published_at = post.publishedAt;
      post.updatedAt = new Date().toISOString();
      post.updated_at = post.updatedAt;
      post.errorMessage = null;
      post.error_message = null;

      console.log(`Published post ${post.id}`);
    } catch (error) {
      post.status = "failed";
      post.errorMessage = JSON.stringify(error.response?.data || error.message);
      post.error_message = post.errorMessage;
      post.updatedAt = new Date().toISOString();
      post.updated_at = post.updatedAt;

      console.error(`Failed post ${post.id}:`, post.errorMessage);
    }
  }
});

// ── Media routes ─────────────────────────────────────────────────────────────

app.get("/api/media", (req, res) => {
  try {
    const files = fs.existsSync(uploadsDir) ? fs.readdirSync(uploadsDir) : [];
    const media = files.map((filename) => {
      const filePath = path.join(uploadsDir, filename);
      const stats = fs.statSync(filePath);
      const id = path.basename(filename, path.extname(filename));
      const ext = path.extname(filename).toLowerCase();
      const isVideo = [".mp4", ".mov", ".avi", ".webm"].includes(ext);
      const publicUrl = `${getBaseUrl(req)}/uploads/${filename}`;
      return {
        id,
        filename,
        url: publicUrl,
        mediaUrl: publicUrl,
        imageUrl: !isVideo ? publicUrl : null,
        videoUrl: isVideo ? publicUrl : null,
        mediaType: isVideo ? "video" : "image",
        fileSize: stats.size,
        createdAt: stats.birthtime.toISOString(),
        updatedAt: stats.mtime.toISOString()
      };
    });
    res.json({ ok: true, media });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.delete("/api/media/:id", (req, res) => {
  try {
    const id = req.params.id;
    const files = fs.existsSync(uploadsDir) ? fs.readdirSync(uploadsDir) : [];
    const filename = files.find((f) => path.basename(f, path.extname(f)) === id);
    if (!filename) return res.status(404).json({ ok: false, error: "Media not found." });
    fs.unlinkSync(path.join(uploadsDir, filename));
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.delete("/api/posts/:id", (req, res) => {
  const index = posts.findIndex((p) => p.id === req.params.id);
  if (index === -1) return res.status(404).json({ ok: false, error: "Post not found." });
  posts.splice(index, 1);
  res.json({ ok: true });
});

// ── AI stub routes ────────────────────────────────────────────────────────────

app.post("/api/ai/list-models", (req, res) => {
  const provider = req.body.provider || "gemini";
  const modelsByProvider = {
    gemini: [
      { id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", type: "text" },
      { id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", type: "text" },
      { id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", type: "text" }
    ],
    openai: [
      { id: "gpt-4o", name: "GPT-4o", type: "text" },
      { id: "gpt-4o-mini", name: "GPT-4o Mini", type: "text" },
      { id: "dall-e-3", name: "DALL-E 3", type: "image" }
    ],
    openrouter: [
      { id: "openai/gpt-4o", name: "GPT-4o via OpenRouter", type: "text" },
      { id: "anthropic/claude-3-haiku", name: "Claude 3 Haiku", type: "text" }
    ]
  };
  res.json({ ok: true, models: modelsByProvider[provider] || [] });
});

app.post("/api/ai/test-model", async (req, res) => {
  try {
    const { provider, model } = req.body;
    if (provider === "gemini" || !provider) {
      await generateWithGemini('Reply with exactly: {"ok":true}', model || "gemini-1.5-flash");
      res.json({ ok: true, message: "Model connection successful." });
    } else {
      res.status(501).json({ ok: false, error: `Provider "${provider}" test not yet implemented.` });
    }
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.post("/api/ai/chat", async (req, res) => {
  try {
    const { message, provider, model } = req.body;
    if (!message) return res.status(400).json({ ok: false, error: "message is required." });
    if (provider === "gemini" || !provider) {
      requireGeminiConfig();
      const text = await generateWithGemini(message, model || "gemini-1.5-flash");
      res.json({ ok: true, reply: text });
    } else {
      res.status(501).json({ ok: false, error: `Chat provider "${provider}" not yet implemented.` });
    }
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get("/api/ai/jobs", (req, res) => res.json({ ok: true, jobs: [] }));

app.get("/api/ai/jobs/:id", (req, res) =>
  res.status(404).json({ ok: false, error: "AI job not found." })
);

app.post("/api/ai/jobs/:id/retry-failed", (req, res) =>
  res.status(404).json({ ok: false, error: "AI job not found." })
);

app.post("/api/ai/jobs/:jobId/items/:itemId/retry", (req, res) =>
  res.status(404).json({ ok: false, error: "AI job item not found." })
);

app.post("/api/ai/jobs/:jobId/items/:itemId/save", (req, res) =>
  res.status(404).json({ ok: false, error: "AI job item not found." })
);

app.post("/api/ai/bulk-edit", (req, res) =>
  res.status(501).json({ ok: false, error: "Bulk edit jobs are not yet implemented on this server." })
);

// ── Inbox routes ──────────────────────────────────────────────────────────────

app.get("/api/inbox/conversations", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/conversations`;
    const response = await axios.get(url, {
      params: {
        platform: "instagram",
        fields: "id,participants,updated_time,messages{id,message,from,created_time}",
        access_token: META_ACCESS_TOKEN
      }
    });
    const convs = (response.data.data || []).map((c) => ({
      id: c.id,
      updatedAt: c.updated_time,
      participants: c.participants?.data || [],
      latestMessage: c.messages?.data?.[0] || null
    }));
    res.json({ ok: true, conversations: convs });
  } catch (error) {
    console.error("Get conversations failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/inbox/sync-conversations", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/conversations`;
    const response = await axios.get(url, {
      params: {
        platform: "instagram",
        fields: "id,participants,updated_time",
        access_token: META_ACCESS_TOKEN
      }
    });
    const convs = response.data.data || [];
    res.json({ ok: true, synced: convs.length, conversations: convs });
  } catch (error) {
    console.error("Sync conversations failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.get("/api/inbox/conversations/:id/messages", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${req.params.id}/messages`;
    const response = await axios.get(url, {
      params: {
        fields: "id,message,from,created_time,attachments",
        access_token: META_ACCESS_TOKEN
      }
    });
    res.json({ ok: true, messages: response.data.data || [] });
  } catch (error) {
    console.error("Get messages failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/inbox/send-text", async (req, res) => {
  try {
    requireMetaConfig();
    const { recipientId, text } = req.body;
    if (!recipientId || !text) {
      return res.status(400).json({ ok: false, error: "recipientId and text are required." });
    }
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/messages`;
    const response = await axios.post(url, {
      recipient: { id: recipientId },
      message: { text },
      access_token: META_ACCESS_TOKEN
    });
    res.json({ ok: true, messageId: response.data?.message_id || response.data?.id });
  } catch (error) {
    console.error("Send text failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/inbox/send-image", async (req, res) => {
  try {
    requireMetaConfig();
    const { recipientId, imageUrl } = req.body;
    if (!recipientId || !imageUrl) {
      return res.status(400).json({ ok: false, error: "recipientId and imageUrl are required." });
    }
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/messages`;
    const response = await axios.post(url, {
      recipient: { id: recipientId },
      message: { attachment: { type: "image", payload: { url: imageUrl, is_reusable: true } } },
      access_token: META_ACCESS_TOKEN
    });
    res.json({ ok: true, messageId: response.data?.message_id || response.data?.id });
  } catch (error) {
    console.error("Send image failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

// ── Comments routes ───────────────────────────────────────────────────────────

app.post("/api/comments/sync-media", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/media`;
    const response = await axios.get(url, {
      params: {
        fields: "id,media_type,media_url,thumbnail_url,caption,timestamp,comments_count",
        access_token: META_ACCESS_TOKEN
      }
    });
    const media = response.data.data || [];
    res.json({ ok: true, synced: media.length, media });
  } catch (error) {
    console.error("Sync media failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.get("/api/comments/media", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/media`;
    const response = await axios.get(url, {
      params: {
        fields: "id,media_type,media_url,thumbnail_url,caption,timestamp,comments_count",
        access_token: META_ACCESS_TOKEN
      }
    });
    res.json({ ok: true, media: response.data.data || [] });
  } catch (error) {
    console.error("Get comment media failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/comments/sync-all", async (req, res) => {
  try {
    requireMetaConfig();
    const mediaUrl = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/media`;
    const mediaResp = await axios.get(mediaUrl, {
      params: { fields: "id", limit: 10, access_token: META_ACCESS_TOKEN }
    });
    const mediaList = mediaResp.data.data || [];
    let total = 0;
    for (const m of mediaList) {
      const commResp = await axios.get(
        `https://graph.facebook.com/${GRAPH_VERSION}/${m.id}/comments`,
        {
          params: {
            fields: "id,text,username,timestamp,like_count,hidden",
            access_token: META_ACCESS_TOKEN
          }
        }
      );
      total += (commResp.data.data || []).length;
    }
    res.json({ ok: true, synced: total });
  } catch (error) {
    console.error("Sync all comments failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/comments/sync", async (req, res) => {
  try {
    requireMetaConfig();
    const { igMediaId } = req.body;
    if (!igMediaId) return res.status(400).json({ ok: false, error: "igMediaId is required." });
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${igMediaId}/comments`;
    const response = await axios.get(url, {
      params: {
        fields: "id,text,username,timestamp,like_count,hidden,replies{id,text,username,timestamp}",
        access_token: META_ACCESS_TOKEN
      }
    });
    const comments = response.data.data || [];
    res.json({ ok: true, synced: comments.length, comments });
  } catch (error) {
    console.error("Sync comments failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.get("/api/comments", async (req, res) => {
  try {
    requireMetaConfig();
    const { igMediaId, search } = req.query;

    const fetchComments = async (mediaId) => {
      const url = `https://graph.facebook.com/${GRAPH_VERSION}/${mediaId}/comments`;
      const response = await axios.get(url, {
        params: {
          fields: "id,text,username,timestamp,like_count,hidden,replies{id,text,username,timestamp}",
          access_token: META_ACCESS_TOKEN
        }
      });
      return (response.data.data || []).map((c) => ({ ...c, igMediaId: mediaId }));
    };

    let comments = [];
    if (igMediaId) {
      comments = await fetchComments(igMediaId);
    } else {
      const mediaUrl = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/media`;
      const mediaResp = await axios.get(mediaUrl, {
        params: { fields: "id", limit: 5, access_token: META_ACCESS_TOKEN }
      });
      for (const m of mediaResp.data.data || []) {
        comments.push(...(await fetchComments(m.id)));
      }
    }

    if (search) {
      const q = search.toLowerCase();
      comments = comments.filter(
        (c) => c.text?.toLowerCase().includes(q) || c.username?.toLowerCase().includes(q)
      );
    }

    res.json({ ok: true, comments });
  } catch (error) {
    console.error("Get comments failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.get("/api/comments/auto-reply/rules", (req, res) => {
  res.json({ ok: true, rules: autoReplyRules });
});

app.post("/api/comments/auto-reply/rules", (req, res) => {
  const rule = { id: randomUUID(), ...req.body, createdAt: new Date().toISOString() };
  autoReplyRules.push(rule);
  res.json({ ok: true, rule });
});

app.patch("/api/comments/auto-reply/rules/:id", (req, res) => {
  const index = autoReplyRules.findIndex((r) => r.id === req.params.id);
  if (index === -1) return res.status(404).json({ ok: false, error: "Rule not found." });
  autoReplyRules[index] = { ...autoReplyRules[index], ...req.body, updatedAt: new Date().toISOString() };
  res.json({ ok: true, rule: autoReplyRules[index] });
});

app.delete("/api/comments/auto-reply/rules/:id", (req, res) => {
  const index = autoReplyRules.findIndex((r) => r.id === req.params.id);
  if (index === -1) return res.status(404).json({ ok: false, error: "Rule not found." });
  autoReplyRules.splice(index, 1);
  res.json({ ok: true });
});

app.post("/api/comments/:commentId/reply", async (req, res) => {
  try {
    requireMetaConfig();
    const { message } = req.body;
    if (!message) return res.status(400).json({ ok: false, error: "message is required." });
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${req.params.commentId}/replies`;
    const response = await axios.post(url, null, {
      params: { message, access_token: META_ACCESS_TOKEN }
    });
    res.json({ ok: true, replyId: response.data?.id });
  } catch (error) {
    console.error("Reply to comment failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/comments/:commentId/private-reply", async (req, res) => {
  try {
    requireMetaConfig();
    const { message } = req.body;
    if (!message) return res.status(400).json({ ok: false, error: "message is required." });
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/messages`;
    const response = await axios.post(url, {
      recipient: { comment_id: req.params.commentId },
      message: { text: message },
      access_token: META_ACCESS_TOKEN
    });
    res.json({ ok: true, messageId: response.data?.message_id });
  } catch (error) {
    console.error("Private reply failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/comments/:commentId/like", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${req.params.commentId}/likes`;
    await axios.post(url, null, { params: { access_token: META_ACCESS_TOKEN } });
    res.json({ ok: true });
  } catch (error) {
    console.error("Like comment failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.post("/api/comments/:commentId/hide", async (req, res) => {
  try {
    requireMetaConfig();
    const hide = req.body.hide === true || req.body.hide === "true";
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${req.params.commentId}`;
    await axios.post(url, null, { params: { hide, access_token: META_ACCESS_TOKEN } });
    res.json({ ok: true });
  } catch (error) {
    console.error("Hide comment failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.delete("/api/comments/:commentId", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${req.params.commentId}`;
    await axios.delete(url, { params: { access_token: META_ACCESS_TOKEN } });
    res.json({ ok: true });
  } catch (error) {
    console.error("Delete comment failed:", error.response?.data || error.message);
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

// ── Webhook routes ────────────────────────────────────────────────────────────

app.get("/api/webhooks/meta", (req, res) => {
  const mode = req.query["hub.mode"];
  const token = req.query["hub.verify_token"];
  const challenge = req.query["hub.challenge"];
  const verifyToken = process.env.META_WEBHOOK_VERIFY_TOKEN || "socialflow_webhook";
  if (mode === "subscribe" && token === verifyToken) {
    res.status(200).send(challenge);
  } else {
    res.status(403).json({ ok: false, error: "Webhook verification failed." });
  }
});

app.post("/api/webhooks/meta", (req, res) => {
  const event = { ...req.body, receivedAt: new Date().toISOString() };
  webhookEvents.unshift(event);
  if (webhookEvents.length > 100) webhookEvents.pop();
  console.log("[Webhook] Event received:", JSON.stringify(event).substring(0, 200));
  res.status(200).json({ ok: true });
});

// ── Debug routes ──────────────────────────────────────────────────────────────

app.get("/api/debug/webhook-events", (req, res) => {
  res.json({ ok: true, events: webhookEvents });
});

app.get("/api/debug/comments", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/media`;
    const mediaResp = await axios.get(url, {
      params: { fields: "id,timestamp", limit: 3, access_token: META_ACCESS_TOKEN }
    });
    const result = [];
    for (const m of mediaResp.data.data || []) {
      const commResp = await axios.get(
        `https://graph.facebook.com/${GRAPH_VERSION}/${m.id}/comments`,
        { params: { fields: "id,text,username,timestamp", access_token: META_ACCESS_TOKEN } }
      );
      result.push({ mediaId: m.id, comments: commResp.data.data || [] });
    }
    res.json({ ok: true, data: result });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

app.get("/api/debug/inbox", async (req, res) => {
  try {
    requireMetaConfig();
    const url = `https://graph.facebook.com/${GRAPH_VERSION}/${IG_USER_ID}/conversations`;
    const response = await axios.get(url, {
      params: {
        platform: "instagram",
        fields: "id,participants,updated_time",
        access_token: META_ACCESS_TOKEN
      }
    });
    res.json({ ok: true, conversations: response.data.data || [] });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.response?.data || error.message });
  }
});

// ── Version check ─────────────────────────────────────────────────────────────

app.get("/api/app-version", (req, res) => {
  res.json({
    ok: true,
    version: "1.0.0",
    buildNumber: 1,
    minVersion: "1.0.0",
    minBuildNumber: 1,
    updateUrl: "",
    message: "A new version of AutoFlow is available. Please update the app to continue."
  });
});

app.use((req, res) => {
  res.status(404).json({
    ok: false,
    error: `Endpoint not found: ${req.method} ${req.originalUrl}`
  });
});

app.listen(PORT, () => {
  console.log(`AutoFlow Backend running on port ${PORT}`);
});