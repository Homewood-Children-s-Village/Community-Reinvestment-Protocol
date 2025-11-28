import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Design system colors from UX/UI spec
        primary: {
          DEFAULT: "#5E3FA3",
          foreground: "#FFFFFF",
          50: "#F3F0F9",
          100: "#E7E0F3",
          200: "#CFC2E7",
          300: "#B7A3DB",
          400: "#9F85CF",
          500: "#5E3FA3",
          600: "#4B3282",
          700: "#382662",
          800: "#261941",
          900: "#130D21",
        },
        secondary: {
          DEFAULT: "#00A0A6",
          foreground: "#FFFFFF",
          50: "#E6F7F8",
          100: "#CCEFF0",
          200: "#99DFE1",
          300: "#66CFD3",
          400: "#33BFC4",
          500: "#00A0A6",
          600: "#008085",
          700: "#006064",
          800: "#004042",
          900: "#002021",
        },
        success: {
          DEFAULT: "#4CAF50",
          foreground: "#FFFFFF",
        },
        error: {
          DEFAULT: "#E53935",
          foreground: "#FFFFFF",
        },
        warning: {
          DEFAULT: "#FFB300",
          foreground: "#333333",
        },
        background: "#F8F8F8",
        surface: "#FFFFFF",
        text: {
          DEFAULT: "#333333",
          muted: "#777777",
        },
        border: "#CCCCCC",
        input: "#CCCCCC",
        ring: "#5E3FA3",
        // shadcn/ui compatible tokens
        card: {
          DEFAULT: "#FFFFFF",
          foreground: "#333333",
        },
        popover: {
          DEFAULT: "#FFFFFF",
          foreground: "#333333",
        },
        muted: {
          DEFAULT: "#F8F8F8",
          foreground: "#777777",
        },
        accent: {
          DEFAULT: "#00A0A6",
          foreground: "#FFFFFF",
        },
        destructive: {
          DEFAULT: "#E53935",
          foreground: "#FFFFFF",
        },
      },
      fontFamily: {
        sans: ["Inter", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"],
      },
      fontSize: {
        // Typography system from design spec
        h1: ["32px", { lineHeight: "1.25", fontWeight: "700" }],
        h2: ["24px", { lineHeight: "1.3", fontWeight: "600" }],
        h3: ["20px", { lineHeight: "1.3", fontWeight: "500" }],
        body: ["16px", { lineHeight: "24px", fontWeight: "400" }],
        caption: ["14px", { lineHeight: "20px", fontWeight: "400" }],
      },
      spacing: {
        // 8px spacing system
        "1": "8px",
        "2": "16px",
        "3": "24px",
        "4": "32px",
        "5": "40px",
        "6": "48px",
        "7": "56px",
        "8": "64px",
      },
      borderRadius: {
        lg: "8px",
        md: "6px",
        sm: "4px",
      },
      boxShadow: {
        card: "0 2px 4px rgba(0, 0, 0, 0.1)",
        "card-hover": "0 4px 8px rgba(0, 0, 0, 0.15)",
      },
      screens: {
        sm: "480px",
        md: "768px",
        lg: "1024px",
        xl: "1280px",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;

