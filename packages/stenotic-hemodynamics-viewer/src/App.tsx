import MenuIcon from "@mui/icons-material/Menu";
import PauseIcon from "@mui/icons-material/Pause";
import PlayArrowIcon from "@mui/icons-material/PlayArrow";
import RestartAltIcon from "@mui/icons-material/RestartAlt";
import SkipNextIcon from "@mui/icons-material/SkipNext";
import SkipPreviousIcon from "@mui/icons-material/SkipPrevious";
import {
  Alert,
  Box,
  Chip,
  Divider,
  Drawer,
  FormControlLabel,
  IconButton,
  LinearProgress,
  Slider,
  Stack,
  Switch,
  ToggleButton,
  ToggleButtonGroup,
  Tooltip,
  Typography,
} from "@mui/material";
import { useEffect, useMemo, useState } from "react";
import {
  loadSnapshotFrame,
  loadVizData,
  prefetchSnapshotFrame,
  rangeForField,
  resolveManifestUrl,
} from "./dataLoader";
import { formatNumber } from "./fieldMath";
import type { FieldName, GeometryView, LoadedSnapshotFrame, LoadedVizData, NumericRange, ViewMode } from "./types";
import ViewerScene from "./ViewerScene";

const modeDefaults: Record<
  ViewMode,
  {
    label: string;
    field: FieldName;
    deformationScale: number;
    glyphs: boolean;
  }
> = {
  flow: {
    label: "Flow",
    field: "speed",
    deformationScale: 5,
    glyphs: true,
  },
  pressure: {
    label: "Pressure",
    field: "pressure",
    deformationScale: 4,
    glyphs: false,
  },
  wall: {
    label: "Wall motion",
    field: "displacement",
    deformationScale: 14,
    glyphs: false,
  },
};

const drawerWidth = 360;

function frameCount(data: LoadedVizData | null): number {
  return data?.frames.length ?? 0;
}

function playbackFps(data: LoadedVizData | null): number {
  const fps = data?.manifest.estimated_playback_fps;
  if (typeof fps === "number" && Number.isFinite(fps) && fps > 0) {
    return Math.min(30, Math.max(1, fps));
  }
  return 8;
}

function modeAvailable(data: LoadedVizData | null, mode: ViewMode): boolean {
  if (!data) {
    return true;
  }
  if (mode === "pressure") {
    return Boolean(data.frames[0]?.fields.pressure?.asset);
  }
  if (mode === "wall") {
    return Boolean(data.frames[0]?.fields.displacement?.asset);
  }
  return true;
}

function rangeLabel(range: NumericRange | null): string {
  if (!range) {
    return "n/a";
  }
  return `${formatNumber(range.min)} - ${formatNumber(range.max)}`;
}

export default function App() {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [mode, setMode] = useState<ViewMode>("flow");
  const [deformationScale, setDeformationScale] = useState(modeDefaults.flow.deformationScale);
  const [showGlyphs, setShowGlyphs] = useState(modeDefaults.flow.glyphs);
  const [geometryView, setGeometryView] = useState<GeometryView>("deformed");
  const [glyphDensity, setGlyphDensity] = useState(7);
  const [useGlobalRange, setUseGlobalRange] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [snapshotIndex, setSnapshotIndex] = useState(0);
  const [data, setData] = useState<LoadedVizData | null>(null);
  const [frame, setFrame] = useState<LoadedSnapshotFrame | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loadingBundle, setLoadingBundle] = useState(true);
  const [loadingFrame, setLoadingFrame] = useState(false);

  const manifestUrl = useMemo(resolveManifestUrl, []);
  const activeField = modeDefaults[mode].field;
  const totalFrames = frameCount(data);
  const hasTimeline = totalFrames > 1;
  const fps = playbackFps(data);
  const activeRange = data && frame ? rangeForField(data, frame, activeField, useGlobalRange) : null;
  const currentRange = data && frame ? rangeForField(data, frame, activeField, false) : null;
  const fieldCatalog = data?.fieldCatalog[activeField];
  const activeTime = frame?.descriptor.time_s ?? data?.frames[snapshotIndex]?.time_s ?? 0;
  const globalDefault = data?.manifest.schema_version === 2;
  const canApplyDisplacement = data?.manifest.coordinate_mode === "reference" && Boolean(frame?.displacement);
  const effectiveGeometryView: GeometryView =
    geometryView === "deformed" && (canApplyDisplacement || data?.manifest.coordinate_mode === "deformed")
      ? "deformed"
      : "reference";
  const effectiveDeformationScale = canApplyDisplacement && effectiveGeometryView === "deformed" ? deformationScale : 0;

  useEffect(() => {
    let active = true;
    setLoadingBundle(true);
    loadVizData(manifestUrl)
      .then((loaded) => {
        if (!active) {
          return;
        }
        setData(loaded);
        setSnapshotIndex(0);
        setUseGlobalRange(loaded.manifest.schema_version === 2);
        setError(null);
      })
      .catch((err: unknown) => {
        if (active) {
          setError(err instanceof Error ? err.message : String(err));
        }
      })
      .finally(() => {
        if (active) {
          setLoadingBundle(false);
        }
      });
    return () => {
      active = false;
    };
  }, [manifestUrl]);

  useEffect(() => {
    if (!data) {
      return;
    }
    if (!modeAvailable(data, mode)) {
      setMode("flow");
    }
  }, [data, mode]);

  useEffect(() => {
    if (!data) {
      return;
    }
    let active = true;
    setLoadingFrame(true);
    loadSnapshotFrame(data, snapshotIndex)
      .then((loadedFrame) => {
        if (!active) {
          return;
        }
        setFrame(loadedFrame);
        if (data.frames.length > 1) {
          prefetchSnapshotFrame(data, (snapshotIndex + 1) % data.frames.length);
        }
      })
      .catch((err: unknown) => {
        if (active) {
          setError(err instanceof Error ? err.message : String(err));
        }
      })
      .finally(() => {
        if (active) {
          setLoadingFrame(false);
        }
      });
    return () => {
      active = false;
    };
  }, [data, snapshotIndex]);

  useEffect(() => {
    if (!playing || !hasTimeline || !data) {
      return;
    }
    const intervalMs = Math.max(34, Math.round(1000 / fps));
    const id = window.setInterval(() => {
      setSnapshotIndex((index) => (index + 1) % data.frames.length);
    }, intervalMs);
    return () => window.clearInterval(id);
  }, [data, fps, hasTimeline, playing]);

  useEffect(() => {
    if (!hasTimeline && playing) {
      setPlaying(false);
    }
  }, [hasTimeline, playing]);

  function applyMode(nextMode: ViewMode): void {
    setMode(nextMode);
    setDeformationScale(modeDefaults[nextMode].deformationScale);
    setShowGlyphs(modeDefaults[nextMode].glyphs);
  }

  function step(delta: number): void {
    if (!data) {
      return;
    }
    setPlaying(false);
    setSnapshotIndex((index) => (index + delta + data.frames.length) % data.frames.length);
  }

  return (
    <Box sx={{ height: "100%", minHeight: 0, bgcolor: "#eef2f3", position: "relative", overflow: "hidden" }}>
      {frame && data ? (
        <ViewerScene
          data={data}
          frame={frame}
          field={activeField}
          mode={mode}
          geometryView={effectiveGeometryView}
          deformationScale={effectiveDeformationScale}
          showGlyphs={mode === "flow" && showGlyphs}
          glyphDensity={glyphDensity}
          colorRange={activeRange}
        />
      ) : (
        <Box sx={{ height: "100%", display: "grid", placeItems: "center", color: "text.secondary" }}>
          <Typography variant="body2">Loading static result bundle</Typography>
        </Box>
      )}

      <Box
        component="header"
        data-viz-panel="header"
        sx={{
          position: "absolute",
          top: { xs: 8, sm: 12 },
          left: { xs: 8, sm: 14 },
          right: { xs: 8, sm: 14 },
          zIndex: 4,
          px: { xs: 1.25, sm: 1.75 },
          py: 1,
          border: "1px solid rgba(20, 31, 43, 0.12)",
          bgcolor: "rgba(248, 250, 250, 0.82)",
          backdropFilter: "blur(14px)",
          display: "flex",
          alignItems: "center",
          gap: 1.25,
          minHeight: 48,
        }}
      >
        <Tooltip title="Open diagnostics">
          <IconButton size="small" onClick={() => setDrawerOpen(true)} aria-label="open diagnostics">
            <MenuIcon fontSize="small" />
          </IconButton>
        </Tooltip>
        <Box sx={{ minWidth: 0, flexGrow: 1 }}>
          <Typography
            variant="subtitle1"
            sx={{ fontWeight: 700, letterSpacing: 0, lineHeight: 1.1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}
          >
            {data?.manifest.case_label ?? "StenoticHemodynamics"}
          </Typography>
          <Typography
            variant="caption"
            sx={{ display: "block", color: "text.secondary", lineHeight: 1.2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}
          >
            Native resolved-FSI demo export
          </Typography>
        </Box>
        {data ? (
          <Stack direction="row" spacing={0.75} sx={{ display: { xs: "none", sm: "flex" } }}>
            <Chip size="small" label={`${data.manifest.severity_percent}% stenosis`} />
            <Chip size="small" label={`t=${formatNumber(activeTime)} s`} />
            <Chip size="small" label={`schema v${data.manifest.schema_version}`} />
          </Stack>
        ) : null}
      </Box>

      {(loadingBundle || loadingFrame) && (
        <LinearProgress
          sx={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            zIndex: 5,
            height: 2,
          }}
        />
      )}

      {error ? (
        <Alert
          severity="error"
          sx={{
            position: "absolute",
            top: { xs: 74, sm: 82 },
            left: { xs: 10, sm: 18 },
            right: { xs: 10, sm: "auto" },
            maxWidth: 720,
            zIndex: 5,
          }}
        >
          {error}
        </Alert>
      ) : null}

      {data && frame ? (
        <Box
          data-viz-panel="legend"
          sx={{
            position: "absolute",
            left: { xs: 8, sm: 14 },
            bottom: { xs: hasTimeline ? 146 : 88, sm: hasTimeline ? 124 : 88 },
            zIndex: 3,
            width: { xs: "calc(100% - 16px)", sm: 330 },
            maxWidth: "calc(100% - 16px)",
            p: 1.25,
            border: "1px solid rgba(20, 31, 43, 0.12)",
            bgcolor: "rgba(248, 250, 250, 0.84)",
            backdropFilter: "blur(14px)",
          }}
        >
          <Stack spacing={0.75}>
            <Stack direction="row" alignItems="baseline" justifyContent="space-between" spacing={1}>
              <Typography variant="caption" sx={{ color: "text.secondary", textTransform: "uppercase", fontWeight: 700, letterSpacing: 0 }}>
                {fieldCatalog?.label ?? modeDefaults[mode].label}
              </Typography>
              <Typography variant="caption" sx={{ color: "text.secondary" }}>
                {fieldCatalog?.units ?? ""}
              </Typography>
            </Stack>
            <Box
              sx={{
                height: 8,
                borderRadius: 0.5,
                background:
                  mode === "pressure"
                    ? "linear-gradient(90deg, #315d83 0%, #d8d5cc 50%, #9b2f3a 100%)"
                    : mode === "wall"
                      ? "linear-gradient(90deg, #506271 0%, #d7d2c2 50%, #b0742c 100%)"
                      : "linear-gradient(90deg, #0f4e56 0%, #d8d5cc 50%, #8f3d54 100%)",
              }}
            />
            <Stack direction="row" justifyContent="space-between" spacing={1}>
              <Typography variant="caption" color="text.secondary">
                {useGlobalRange ? "Global" : "Current"} {rangeLabel(activeRange)}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Frame {snapshotIndex + 1}/{totalFrames}
              </Typography>
            </Stack>
            <Typography variant="caption" color="text.secondary">
              Current {rangeLabel(currentRange)} · geometry {effectiveGeometryView} · deformation {formatNumber(effectiveDeformationScale)}x
            </Typography>
          </Stack>
        </Box>
      ) : null}

      {hasTimeline ? (
        <Box
          data-viz-panel="timeline"
          sx={{
            position: "absolute",
            left: "50%",
            bottom: { xs: 78, sm: 70 },
            transform: "translateX(-50%)",
            zIndex: 4,
            width: { xs: "calc(100% - 16px)", sm: "min(680px, calc(100% - 28px))" },
            px: { xs: 1, sm: 1.5 },
            py: 1,
            border: "1px solid rgba(20, 31, 43, 0.12)",
            bgcolor: "rgba(248, 250, 250, 0.86)",
            backdropFilter: "blur(14px)",
          }}
        >
          <Stack direction="row" alignItems="center" spacing={1.25}>
            <Tooltip title="Previous frame">
              <span>
                <IconButton size="small" onClick={() => step(-1)} disabled={!data} aria-label="previous frame">
                  <SkipPreviousIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
            <Tooltip title={playing ? "Pause" : "Play"}>
              <span>
                <IconButton size="small" onClick={() => setPlaying((value) => !value)} disabled={!data} aria-label={playing ? "pause" : "play"}>
                  {playing ? <PauseIcon fontSize="small" /> : <PlayArrowIcon fontSize="small" />}
                </IconButton>
              </span>
            </Tooltip>
            <Tooltip title="Next frame">
              <span>
                <IconButton size="small" onClick={() => step(1)} disabled={!data} aria-label="next frame">
                  <SkipNextIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
            <Slider
              size="small"
              min={0}
              max={Math.max(totalFrames - 1, 0)}
              step={1}
              value={snapshotIndex}
              onChange={(_, value) => {
                setPlaying(false);
                setSnapshotIndex(value as number);
              }}
              aria-label="timeline"
              sx={{ mx: 0.5 }}
            />
            <Typography variant="caption" color="text.secondary" sx={{ whiteSpace: "nowrap", minWidth: 66, textAlign: "right" }}>
              {formatNumber(activeTime)} s
            </Typography>
          </Stack>
        </Box>
      ) : null}

      <Box
        data-viz-panel="mode-rail"
        sx={{
          position: "absolute",
          left: "50%",
          bottom: { xs: 10, sm: 14 },
          transform: "translateX(-50%)",
          zIndex: 4,
          maxWidth: "calc(100% - 16px)",
          border: "1px solid rgba(20, 31, 43, 0.12)",
          bgcolor: "rgba(248, 250, 250, 0.88)",
          backdropFilter: "blur(14px)",
          p: 0.5,
        }}
      >
        <ToggleButtonGroup
          exclusive
          value={mode}
          size="small"
          onChange={(_, value: ViewMode | null) => {
            if (value && modeAvailable(data, value)) {
              applyMode(value);
            }
          }}
          aria-label="view mode"
          sx={{
            "& .MuiToggleButton-root": {
              px: { xs: 1, sm: 1.6 },
              minWidth: { xs: 86, sm: 112 },
              textTransform: "none",
              letterSpacing: 0,
              whiteSpace: "nowrap",
            },
          }}
        >
          {(["flow", "pressure", "wall"] as ViewMode[]).map((option) => (
            <ToggleButton key={option} value={option} disabled={!modeAvailable(data, option)} aria-label={modeDefaults[option].label}>
              {modeDefaults[option].label}
            </ToggleButton>
          ))}
        </ToggleButtonGroup>
      </Box>

      <Drawer
        anchor="right"
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        ModalProps={{ keepMounted: true }}
        PaperProps={{
          sx: {
            width: { xs: "min(92vw, 360px)", sm: drawerWidth },
            p: 2,
          },
        }}
      >
        <Stack spacing={2}>
          <Box>
            <Typography variant="subtitle1" sx={{ fontWeight: 700, letterSpacing: 0 }}>
              Export Diagnostics
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {data?.manifest.case_id ?? "No manifest loaded"}
            </Typography>
          </Box>
          <Divider />
          <Stack spacing={1.2}>
            <Box>
              <Typography variant="body2" color="text.secondary" gutterBottom>
                Geometry
              </Typography>
              <ToggleButtonGroup
                exclusive
                size="small"
                value={effectiveGeometryView}
                onChange={(_, value: GeometryView | null) => {
                  if (value && (value === "reference" || canApplyDisplacement || data?.manifest.coordinate_mode === "deformed")) {
                    setGeometryView(value);
                  }
                }}
                aria-label="geometry view"
              >
                <ToggleButton value="reference" disabled={data?.manifest.coordinate_mode === "deformed"} aria-label="reference geometry">
                  Reference
                </ToggleButton>
                <ToggleButton value="deformed" disabled={!canApplyDisplacement && data?.manifest.coordinate_mode !== "deformed"} aria-label="deformed geometry">
                  Deformed
                </ToggleButton>
              </ToggleButtonGroup>
            </Box>
            <FormControlLabel
              control={<Switch checked={useGlobalRange} onChange={(event) => setUseGlobalRange(event.target.checked)} />}
              label="Fixed global color range"
            />
            <FormControlLabel
              control={<Switch checked={showGlyphs} onChange={(event) => setShowGlyphs(event.target.checked)} disabled={mode !== "flow"} />}
              label="Velocity glyphs"
            />
            <Box>
              <Typography variant="body2" color="text.secondary" gutterBottom>
                Deformation scale
              </Typography>
              <Slider
                min={0}
                max={24}
                step={0.5}
                value={deformationScale}
                onChange={(_, value) => setDeformationScale(value as number)}
                valueLabelDisplay="auto"
              />
            </Box>
            <Box>
              <Typography variant="body2" color="text.secondary" gutterBottom>
                Glyph density
              </Typography>
              <Slider
                min={2}
                max={22}
                step={1}
                value={glyphDensity}
                onChange={(_, value) => setGlyphDensity(value as number)}
                disabled={mode !== "flow" || !showGlyphs}
                valueLabelDisplay="auto"
              />
            </Box>
            <Tooltip title="Reset controls">
              <IconButton
                sx={{ alignSelf: "flex-start" }}
                onClick={() => {
                  applyMode("flow");
                  setGeometryView("deformed");
                  setGlyphDensity(7);
                  setUseGlobalRange(globalDefault);
                  setPlaying(false);
                  setSnapshotIndex(0);
                }}
                aria-label="reset controls"
              >
                <RestartAltIcon />
              </IconButton>
            </Tooltip>
          </Stack>
          <Divider />
          {data ? (
            <Stack spacing={1}>
              <Typography variant="body2">
                Schema v{data.manifest.schema_version} · {totalFrames} frame{totalFrames === 1 ? "" : "s"}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Nodes {data.manifest.geometry.node_count.toLocaleString()} · surface triangles{" "}
                {data.manifest.geometry.surface_triangle_count.toLocaleString()}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Coordinate mode {data.manifest.coordinate_mode} · displayed geometry {effectiveGeometryView}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Source {data.manifest.source.input_production_dir ? String(data.manifest.source.input_production_dir) : "direct bundle"}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {data.manifest.claim_boundary}
              </Typography>
            </Stack>
          ) : null}
        </Stack>
      </Drawer>
    </Box>
  );
}
