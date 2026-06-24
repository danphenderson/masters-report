import { spawn } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PNG } from "pngjs";
import { chromium } from "@playwright/test";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const distDir = join(root, "dist");
const port = Number.parseInt(process.env.VIZ_BROWSER_SMOKE_PORT ?? "4173", 10);
const host = "127.0.0.1";
const url = `http://${host}:${port}/`;
const missingFieldsUrl = `${url}?manifest=/data/missing-fields/manifest.json`;
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

function demoAssetPath(path) {
  return `../demo/${path}`;
}

function rewriteAssetForDemo(asset) {
  return asset ? { ...asset, path: demoAssetPath(asset.path) } : asset;
}

function createMissingFieldsManifest() {
  const demoManifestPath = join(distDir, "data", "demo", "manifest.json");
  const demoManifest = JSON.parse(readFileSync(demoManifestPath, "utf8"));
  const firstSnapshot = demoManifest.snapshots[0];
  const velocityField = {
    ...firstSnapshot.fields.velocity,
    asset: rewriteAssetForDemo(firstSnapshot.fields.velocity.asset),
  };
  const speedRange = demoManifest.global_ranges?.speed_cm_s ?? firstSnapshot.ranges.speed_cm_s;
  const manifest = {
    ...demoManifest,
    case_id: "missing-field-smoke",
    case_label: "Missing field smoke fixture",
    result_class: "native_resolved_fsi_missing_field_smoke",
    snapshot_count: 1,
    estimated_playback_fps: 0,
    time_axis: [{ frame_id: firstSnapshot.id, time_s: firstSnapshot.time_s, delta_t_s: null }],
    available_fields: demoManifest.available_fields.filter((field) => field.name === "velocity" || field.name === "speed"),
    global_ranges: { speed_cm_s: speedRange },
    source: {
      fixture: true,
      purpose: "browser smoke missing-field coverage",
    },
    geometry: {
      ...demoManifest.geometry,
      reference_positions: rewriteAssetForDemo(demoManifest.geometry.reference_positions),
      surface_indices: rewriteAssetForDemo(demoManifest.geometry.surface_indices),
      tetra_indices_debug: null,
    },
    snapshots: [
      {
        ...firstSnapshot,
        fields: { velocity: velocityField },
        derived: null,
        ranges: { speed_cm_s: firstSnapshot.ranges.speed_cm_s },
      },
    ],
    skipped_snapshots: ["snapshot-t0p0400"],
    sidecars: {
      restart_metadata: {
        label: "restart metadata",
        status: "metadata",
        source_path: "restart_metadata.json",
      },
    },
    observations: {
      section41_observations: {
        label: "section41 observations",
        status: "missing",
        source_path: "section41_observations.csv",
      },
    },
  };

  const targetDir = join(distDir, "data", "missing-fields");
  mkdirSync(targetDir, { recursive: true });
  writeFileSync(join(targetDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
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

async function assertDiagnosticsDrawer(page, viewportName) {
  await page.getByLabel("open diagnostics").click();
  const diagnostics = page.locator("[data-slice-diagnostics='surface']");
  await diagnostics.waitFor({ state: "visible", timeout: 5_000 });
  const text = await diagnostics.innerText();
  if (!text.includes("Surface Slice Diagnostics")) {
    fail(`${viewportName} diagnostics drawer did not show the slice diagnostics title`);
  }
  if (!text.includes("inspection aid only")) {
    fail(`${viewportName} diagnostics drawer did not show the inspection-only boundary`);
  }
  if (!/\baxis\s+[xyz]\b/.test(text)) {
    fail(`${viewportName} diagnostics drawer did not report the sampled axis`);
  }
  if (!/\bsamples\b/.test(text)) {
    fail(`${viewportName} diagnostics drawer did not report surface sample count`);
  }
  await page.keyboard.press("Escape");
  await diagnostics.waitFor({ state: "hidden", timeout: 5_000 });
}

async function assertFieldToggles(page, viewportName) {
  const legend = page.locator("[data-viz-panel='legend']");
  await legend.waitFor({ state: "visible", timeout: 5_000 });
  for (const field of ["speed", "pressure", "displacement"]) {
    const toggle = page.locator(`[data-field-toggle='${field}']`);
    await toggle.waitFor({ state: "visible", timeout: 5_000 });
    if (!(await toggle.isEnabled())) {
      fail(`${viewportName} ${field} field toggle was disabled for the full demo manifest`);
    }
  }
  await page.locator("[data-field-toggle='pressure']").click();
  if (!(await legend.innerText()).toLowerCase().includes("pressure")) {
    fail(`${viewportName} pressure toggle did not update the colorbar label`);
  }
  await page.locator("[data-field-toggle='displacement']").click();
  if (!(await legend.innerText()).toLowerCase().includes("displacement")) {
    fail(`${viewportName} displacement toggle did not update the colorbar label`);
  }
  await page.locator("[data-field-toggle='speed']").click();
  const legendText = (await legend.innerText()).toLowerCase();
  if (!legendText.includes("velocity magnitude") || !legendText.includes("current") || !legendText.includes("global")) {
    fail(`${viewportName} velocity magnitude colorbar did not report field and range labels`);
  }
}

async function assertMissingFieldManifest(page) {
  await page.setViewportSize({ width: 1280, height: 820 });
  await page.goto(missingFieldsUrl, { waitUntil: "networkidle" });
  await page.locator("canvas").first().waitFor({ state: "visible", timeout: 15_000 });
  const pressureToggle = page.locator("[data-field-toggle='pressure']");
  const displacementToggle = page.locator("[data-field-toggle='displacement']");
  if (await pressureToggle.isEnabled()) {
    fail("missing-field manifest left pressure toggle enabled");
  }
  if (await displacementToggle.isEnabled()) {
    fail("missing-field manifest left displacement toggle enabled");
  }
  const pressureLabel = await pressureToggle.getAttribute("aria-label");
  const displacementLabel = await displacementToggle.getAttribute("aria-label");
  if (!pressureLabel?.includes("not present in this manifest")) {
    fail("missing-field manifest did not expose the pressure disabled reason");
  }
  if (!displacementLabel?.includes("not present in this manifest")) {
    fail("missing-field manifest did not expose the displacement disabled reason");
  }

  await page.getByLabel("open diagnostics").click();
  const drawerText = (await page.locator(".MuiDrawer-paper").innerText()).toLowerCase();
  for (const expected of [
    "artifact/operator aid",
    "coordinates: reference",
    "1 skipped snapshot",
    "1 sidecar",
    "1 observation artifact",
    "missing from manifest",
    "Skipped snapshots: snapshot-t0p0400",
    "restart metadata",
    "section41 observations",
    "missing source section41_observations.csv",
  ]) {
    if (!drawerText.includes(expected.toLowerCase())) {
      fail(`missing-field diagnostics drawer did not include "${expected}"`);
    }
  }
  await page.keyboard.press("Escape");
}

async function run() {
  createMissingFieldsManifest();
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
        await assertFieldToggles(page, viewport.name);
        await assertDiagnosticsDrawer(page, viewport.name);
      }
      await assertMissingFieldManifest(page);
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
