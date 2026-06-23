import React from "react";
import ReactDOM from "react-dom/client";
import { CssBaseline, ThemeProvider, createTheme } from "@mui/material";
import App from "./App";
import "./styles.css";

const theme = createTheme({
  palette: {
    mode: "light",
    primary: {
      main: "#234e59",
    },
    secondary: {
      main: "#9b2f3a",
    },
    warning: {
      main: "#b7791f",
    },
    background: {
      default: "#eef2f3",
      paper: "#ffffff",
    },
    text: {
      primary: "#17202f",
      secondary: "#52616b",
    },
  },
  shape: {
    borderRadius: 5,
  },
  typography: {
    fontFamily: [
      "Inter",
      "ui-sans-serif",
      "system-ui",
      "-apple-system",
      "BlinkMacSystemFont",
      "Segoe UI",
      "sans-serif",
    ].join(","),
    h6: {
      fontWeight: 650,
    },
    button: {
      textTransform: "none",
      letterSpacing: 0,
    },
  },
  components: {
    MuiButtonBase: {
      defaultProps: {
        disableRipple: true,
      },
    },
    MuiTooltip: {
      defaultProps: {
        arrow: true,
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          borderRadius: 5,
          backgroundColor: "rgba(255, 255, 255, 0.64)",
          border: "1px solid rgba(23, 32, 47, 0.12)",
        },
      },
    },
    MuiToggleButton: {
      styleOverrides: {
        root: {
          borderRadius: 4,
          borderColor: "rgba(23, 32, 47, 0.16)",
          color: "#17202f",
          "&.Mui-selected": {
            backgroundColor: "#17202f",
            color: "#ffffff",
          },
          "&.Mui-selected:hover": {
            backgroundColor: "#243041",
          },
        },
      },
    },
  },
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <App />
    </ThemeProvider>
  </React.StrictMode>,
);
