import { spawn } from "node:child_process";
import { PNG } from "pngjs";
import { chromium } from "@playwright/test";

const port = Number.parseInt(process.env.VIZ_BROWSER_SMOKE_PORT ?? "4173", 10);
const host = "127.0.0.1";
const url = `http://${host}:${port}/`;
const viewports = [
  { name: "desktop", width: 1280, height: 820 },
  { name: "mobile", width: 390, height: 844 },
];

function fail(message) {
  throw new Error(`browser smoke failed: ${message}`);
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForServer() {
  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return;
      }
    } catch {
      // Keep polling while Vite preview starts.
    }
    await wait(250);
  }
  fail(`Vite preview did not become ready at ${url}`);
}

function assertVariedImage(buffer, label) {
  const png = PNG.sync.read(buffer);
  const seen = new Set();
  for (let offset = 0; offset < png.data.length; offset += 4 * 31) {
    const alpha = png.data[offset + 3];
    if (alpha === 0) {
      continue;
    }
    seen.add(`${png.data[offset]},${png.data[offset + 1]},${png.data[offset + 2]}`);
    if (seen.size > 12) {
      return;
    }
  }
  fail(`${label} screenshot did not contain enough color variation`);
}

function overlapArea(a, b) {
  const left = Math.max(a.left, b.left);
  const right = Math.min(a.right, b.right);
  const top = Math.max(a.top, b.top);
  const bottom = Math.min(a.bottom, b.bottom);
  return Math.max(0, right - left) * Math.max(0, bottom - top);
}

async function assertPanels(page, viewportName) {
  const panels = await page.locator("[data-viz-panel]").evaluateAll((nodes) =>
    nodes.map((node) => {
      const rect = node.getBoundingClientRect();
      return {
        label: node.getAttribute("data-viz-panel") ?? "panel",
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom,
        width: rect.width,
        height: rect.height,
      };
    }),
  );
  for (const panel of panels) {
    if (panel.width <= 0 || panel.height <= 0) {
      fail(`${viewportName} ${panel.label} has empty bounds`);
    }
    if (panel.left < -1 || panel.top < -1 || panel.right > page.viewportSize().width + 1 || panel.bottom > page.viewportSize().height + 1) {
      fail(`${viewportName} ${panel.label} extends outside the viewport`);
    }
  }
  for (let i = 0; i < panels.length; i += 1) {
    for (let j = i + 1; j < panels.length; j += 1) {
      const area = overlapArea(panels[i], panels[j]);
      if (area > 16) {
        fail(`${viewportName} panels overlap: ${panels[i].label} and ${panels[j].label}`);
      }
    }
  }
}

async function run() {
  const preview = spawn(
    "npx",
    ["vite", "preview", "--host", host, "--port", String(port), "--strictPort"],
    { stdio: ["ignore", "pipe", "pipe"] },
  );
  let stderr = "";
  preview.stderr.on("data", (chunk) => {
    stderr += chunk.toString();
  });
  try {
    await waitForServer();
    const browser = await chromium.launch({ channel: process.env.PLAYWRIGHT_CHROME_CHANNEL ?? "chrome" });
    try {
      const page = await browser.newPage();
      for (const viewport of viewports) {
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
        await page.goto(url, { waitUntil: "networkidle" });
        const canvas = page.locator("canvas").first();
        await canvas.waitFor({ state: "visible", timeout: 15_000 });
        await page.waitForTimeout(500);
        const box = await canvas.boundingBox();
        if (!box || box.width < viewport.width * 0.8 || box.height < viewport.height * 0.8) {
          fail(`${viewport.name} canvas is not full-bleed`);
        }
        assertVariedImage(await canvas.screenshot({ animations: "disabled" }), `${viewport.name} canvas`);
        await assertPanels(page, viewport.name);
      }
    } finally {
      await browser.close();
    }
  } finally {
    preview.kill("SIGTERM");
    await wait(250);
    if (preview.exitCode === null) {
      preview.kill("SIGKILL");
    }
  }
  if (stderr.includes("error")) {
    fail(stderr.trim());
  }
  console.log(`browser_smoke_ok,viewports=${viewports.map((viewport) => viewport.name).join(";")}`);
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
