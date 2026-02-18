import { Client } from "@notionhq/client";
import { markdownToBlocks } from "@tryfabric/martian";
import fs from "fs";
import path from "path";
import os from "os";
import yaml from "js-yaml";

const NOTION_TOKEN = process.env.NOTION_TOKEN;
if (!NOTION_TOKEN) {
  console.error("NOTION_TOKEN 환경변수가 필요합니다.");
  process.exit(1);
}

const args = process.argv.slice(2);
const yamlArg = args.find((a) => a.endsWith(".yaml") || a.endsWith(".yml"));
const SYNC_FILE = yamlArg
  ? path.resolve(yamlArg)
  : path.resolve(".notion-sync.yaml");
const BASE_DIR = path.dirname(SYNC_FILE);

const notion = new Client({ auth: NOTION_TOKEN, notionVersion: "2025-09-03" });

const REQUIRED_FIELDS = ["title", "Sync ID"];
const SKIP_KEYS = new Set(["file", "title"]);

const dbCache = new Map();

async function getDbInfo(databaseId) {
  if (dbCache.has(databaseId)) return dbCache.get(databaseId);
  const db = await notion.databases.retrieve({ database_id: databaseId });
  const dsId = db.data_sources[0].id;
  const ds = await notion.dataSources.retrieve({ data_source_id: dsId });
  const info = { dsId, schema: ds.properties };
  dbCache.set(databaseId, info);
  return info;
}

let userCache = null;

async function resolveUserId(name) {
  if (!name) return null;
  if (!userCache) {
    const res = await notion.users.list();
    userCache = res.results.filter((u) => u.type === "person");
  }
  const user = userCache.find((u) => u.name === name || u.name?.includes(name));
  return user?.id || null;
}

async function buildProperties(entry, databaseId) {
  const missing = REQUIRED_FIELDS.filter((f) => !entry[f]);
  if (missing.length > 0) {
    throw new Error(`필수 필드 누락: ${missing.join(", ")}`);
  }

  const { schema } = await getDbInfo(databaseId);
  const props = {};

  const titlePropName = Object.keys(schema).find((k) => schema[k].type === "title");
  if (titlePropName) {
    props[titlePropName] = { title: [{ text: { content: entry.title } }] };
  }

  for (const [key, value] of Object.entries(entry)) {
    if (SKIP_KEYS.has(key) || value === "" || value == null) continue;

    if (key === "Parent") {
      const parentPageId = await findPageBySyncId(databaseId, value);
      if (!parentPageId) throw new Error(`Parent를 찾을 수 없습니다: ${value}`);
      props["Parent"] = { relation: [{ id: parentPageId }] };
      continue;
    }

    const propSchema = schema[key];
    if (!propSchema) continue;

    switch (propSchema.type) {
      case "rich_text":
        props[key] = { rich_text: [{ text: { content: String(value) } }] };
        break;
      case "select":
        props[key] = { select: { name: String(value) } };
        break;
      case "multi_select": {
        const names = Array.isArray(value) ? value : String(value).split(",").map((v) => v.trim());
        props[key] = { multi_select: names.map((n) => ({ name: n })) };
        break;
      }
      case "number":
        props[key] = { number: Number(value) };
        break;
      case "checkbox":
        props[key] = { checkbox: Boolean(value) };
        break;
      case "people": {
        const userId = await resolveUserId(String(value));
        if (userId) props[key] = { people: [{ id: userId }] };
        else console.warn(`  사용자를 찾을 수 없습니다: ${value}`);
        break;
      }
      case "relation":
        props[key] = { relation: [{ id: String(value) }] };
        break;
      case "date":
        props[key] = { date: { start: String(value) } };
        break;
      case "url":
        props[key] = { url: String(value) };
        break;
      case "email":
        props[key] = { email: String(value) };
        break;
      case "phone_number":
        props[key] = { phone_number: String(value) };
        break;
      default:
        break;
    }
  }

  return props;
}

function loadSyncConfig() {
  const raw = fs.readFileSync(SYNC_FILE, "utf-8");
  return yaml.load(raw);
}

const UPLOAD_API_VERSION = "2025-09-03";

const MIME_MAP = {
  ".pdf": "application/pdf",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  ".doc": "application/msword",
  ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ".xls": "application/vnd.ms-excel",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  ".ppt": "application/vnd.ms-powerpoint",
  ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  ".zip": "application/zip",
  ".txt": "text/plain",
  ".csv": "text/csv",
  ".json": "application/json",
  ".yaml": "text/yaml",
  ".yml": "text/yaml",
  ".mp4": "video/mp4",
  ".mp3": "audio/mpeg",
};

async function notionUploadFetch(endpoint, options = {}) {
  const res = await fetch(`https://api.notion.com${endpoint}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${NOTION_TOKEN}`,
      "Notion-Version": UPLOAD_API_VERSION,
      ...options.headers,
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Notion API 오류 (${res.status}): ${body}`);
  }
  return res.json();
}

async function uploadFile(filePath) {
  const filename = path.basename(filePath);
  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_MAP[ext] || "application/octet-stream";

  const upload = await notionUploadFetch("/v1/file_uploads", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mode: "single_part", filename, content_type: contentType }),
  });

  const fileBuffer = fs.readFileSync(filePath);
  const formData = new FormData();
  formData.append("file", new Blob([fileBuffer], { type: contentType }), filename);

  await notionUploadFetch(`/v1/file_uploads/${upload.id}/send`, {
    method: "POST",
    body: formData,
  });

  return upload.id;
}

const ATTACH_RE = /^\{\{attach:\s*(.+?)\}\}$/;

function matchAttach(block) {
  if (block.type !== "paragraph") return null;
  const texts = block.paragraph?.rich_text;
  if (texts?.length !== 1) return null;
  const text = texts[0].plain_text || texts[0].text?.content || "";
  return text.trim().match(ATTACH_RE);
}

async function processAttachments(blocks) {
  let hasFileUpload = false;

  async function walk(blockList) {
    const result = [];
    for (const block of blockList) {
      const match = matchAttach(block);
      if (match) {
        const raw = match[1].trim();
        const expanded = raw.startsWith("~") ? raw.replace("~", os.homedir()) : raw;
        const absPath = path.isAbsolute(expanded) ? expanded : path.resolve(BASE_DIR, expanded);
        if (fs.existsSync(absPath)) {
          console.log(`  파일 첨부: ${raw}`);
          const uploadId = await uploadFile(absPath);
          result.push({
            type: "file",
            file: { type: "file_upload", file_upload: { id: uploadId } },
          });
          hasFileUpload = true;
        } else {
          console.warn(`  첨부 파일 없음: ${raw} (건너뜀)`);
        }
        continue;
      }

      const data = block[block.type];
      const children = data?.children || block.children;
      if (children?.length) {
        const processed = await walk(children);
        if (data?.children) data.children = processed;
        else if (block.children) block.children = processed;
      }

      result.push(block);
    }
    return result;
  }

  const blocks2 = await walk(blocks);
  return { blocks: blocks2, hasFileUpload };
}

const KEEP_CHILDREN_TYPES = new Set(["table", "column_list", "toggle", "synced_block"]);

function flattenDeepChildren(block, depth = 0) {
  const type = block.type;
  const data = block[type];
  if (!data?.children && !block.children) return block;

  const children = data?.children || block.children;
  if (!children) return block;

  if (KEEP_CHILDREN_TYPES.has(type)) {
    if (data?.children) {
      data.children = children.map((c) => flattenDeepChildren(c, depth));
    }
    return block;
  }

  if (depth < 1) {
    if (data?.children) {
      data.children = children.map((c) => flattenDeepChildren(c, depth + 1));
    }
    return block;
  }

  if (data?.children) delete data.children;
  if (block.children) delete block.children;
  return block;
}

function sanitizeBlocks(blocks) {
  return blocks.map((block) => flattenDeepChildren(block, 0));
}

async function resolveDataSourceId(databaseId) {
  const { dsId } = await getDbInfo(databaseId);
  return dsId;
}

async function findPageBySyncId(databaseId, syncId) {
  const dsId = await resolveDataSourceId(databaseId);
  const res = await notion.dataSources.query({
    data_source_id: dsId,
    filter: {
      property: "Sync ID",
      rich_text: { equals: syncId },
    },
    page_size: 1,
  });
  return res.results[0]?.id || null;
}

async function createPage(databaseId, properties, blocks) {
  const dsId = await resolveDataSourceId(databaseId);
  const page = await notion.pages.create({
    parent: { data_source_id: dsId },
    properties,
    children: blocks.slice(0, 100),
  });

  if (blocks.length > 100) {
    await appendBlocks(page.id, blocks.slice(100));
  }

  return page.id;
}

async function appendBlocks(pageId, blocks, useUploadApi = false) {
  for (let i = 0; i < blocks.length; i += 100) {
    if (useUploadApi) {
      await notionUploadFetch(`/v1/blocks/${pageId}/children`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ children: blocks.slice(i, i + 100) }),
      });
    } else {
      await notion.blocks.children.append({
        block_id: pageId,
        children: blocks.slice(i, i + 100),
      });
    }
  }
}

async function syncEntry(databaseId, entry) {
  const filePath = path.join(BASE_DIR, entry.file);

  if (!fs.existsSync(filePath)) {
    console.warn(`  파일 없음: ${entry.file} (건너뜀)`);
    return;
  }

  const markdown = fs.readFileSync(filePath, "utf-8");
  const rawBlocks = markdownToBlocks(markdown.trim());
  const sanitized = sanitizeBlocks(rawBlocks);
  const { blocks, hasFileUpload } = await processAttachments(sanitized);

  const properties = await buildProperties(entry, databaseId);
  const existingPageId = await findPageBySyncId(databaseId, entry["Sync ID"]);

  if (existingPageId) {
    console.log(`  업데이트: ${entry.file} → ${entry.title} (${entry["Sync ID"]})`);
    await notion.pages.update({ page_id: existingPageId, properties, erase_content: true });
    await appendBlocks(existingPageId, blocks, hasFileUpload);
  } else {
    console.log(`  새로 생성: ${entry.file} → ${entry.title} (${entry["Sync ID"]})`);
    if (hasFileUpload) {
      const dsId = await resolveDataSourceId(databaseId);
      const page = await notion.pages.create({ parent: { data_source_id: dsId }, properties });
      await appendBlocks(page.id, blocks, true);
    } else {
      await createPage(databaseId, properties, blocks);
    }
  }

  console.log(`  완료: ${entry.file}`);
}

async function syncPageEntry(entry) {
  const filePath = path.join(BASE_DIR, entry.file);

  if (!fs.existsSync(filePath)) {
    console.warn(`  파일 없음: ${entry.file} (건너뜀)`);
    return;
  }

  const pageId = entry.page_id;
  const markdown = fs.readFileSync(filePath, "utf-8");
  const rawBlocks = markdownToBlocks(markdown.trim());
  const sanitized = sanitizeBlocks(rawBlocks);
  const { blocks, hasFileUpload } = await processAttachments(sanitized);

  if (!entry.title) {
    throw new Error(`필수 필드 누락: title (${entry.file})`);
  }
  const updatePayload = {
    page_id: pageId,
    properties: {
      title: { title: [{ text: { content: entry.title } }] },
    },
    erase_content: true,
  };

  console.log(`  업데이트: ${entry.file} → ${entry.title || pageId}`);
  await notion.pages.update(updatePayload);
  await appendBlocks(pageId, blocks, hasFileUpload);
  console.log(`  완료: ${entry.file}`);
}

function groupByDepth(pages) {
  const idSet = new Set(pages.map((p) => p["Sync ID"]));
  const depthOf = (entry) => {
    let d = 0;
    let cur = entry;
    while (cur.Parent && idSet.has(cur.Parent)) {
      d++;
      cur = pages.find((p) => p["Sync ID"] === cur.Parent);
    }
    return d;
  };

  const levels = new Map();
  for (const entry of pages) {
    const d = depthOf(entry);
    if (!levels.has(d)) levels.set(d, []);
    levels.get(d).push(entry);
  }

  return [...levels.keys()].sort((a, b) => a - b).map((d) => levels.get(d));
}

function normalizeConfig(config) {
  if (config.databases) return config.databases;
  if (config.database_id && config.pages) return [{ database_id: config.database_id, pages: config.pages }];
  throw new Error("잘못된 설정 형식: databases 또는 database_id + pages가 필요합니다.");
}

async function syncDatabase(db, filterFiles) {
  const databaseId = db.database_id;
  let pages = db.pages;

  if (filterFiles.length > 0) {
    pages = pages.filter((e) => filterFiles.includes(e.file));
    if (pages.length === 0) return;
  }

  const levels = groupByDepth(pages);
  const total = pages.length;

  console.log(`DB: ${databaseId}`);
  console.log(`동기화 대상: ${total}개 파일 (${levels.length}단계)\n`);

  const CONCURRENCY = 10;
  for (const level of levels) {
    for (let i = 0; i < level.length; i += CONCURRENCY) {
      const batch = level.slice(i, i + CONCURRENCY);
      await Promise.allSettled(
        batch.map(async (entry) => {
          try {
            await syncEntry(databaseId, entry);
          } catch (err) {
            console.error(`  실패: ${entry.file} - ${err.message}`);
          }
        })
      );
    }
  }
}

async function syncPages(pages, filterFiles) {
  let targets = pages;
  if (filterFiles.length > 0) {
    targets = targets.filter((e) => filterFiles.includes(e.file));
  }
  if (targets.length === 0) return;

  console.log(`Pages: ${targets.length}개 파일\n`);

  const CONCURRENCY = 10;
  for (let i = 0; i < targets.length; i += CONCURRENCY) {
    const batch = targets.slice(i, i + CONCURRENCY);
    await Promise.allSettled(
      batch.map(async (entry) => {
        try {
          await syncPageEntry(entry);
        } catch (err) {
          console.error(`  실패: ${entry.file} - ${err.message}`);
        }
      })
    );
  }
}

async function main() {
  const config = loadSyncConfig();
  const databases = normalizeConfig(config);
  const filterFiles = args.filter((a) => !a.endsWith(".yaml") && !a.endsWith(".yml"));

  for (const db of databases) {
    await syncDatabase(db, filterFiles);
  }

  if (config.pages) {
    await syncPages(config.pages, filterFiles);
  }

  console.log("\n동기화 완료");
}

main();
