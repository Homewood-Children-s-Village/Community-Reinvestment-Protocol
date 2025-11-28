import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "@/providers";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "The Village - Community Reinvestment Platform",
  description:
    "Transform community participation into verifiable progress. Log volunteer hours, earn Time Dollars, and invest in neighborhood projects.",
  keywords: [
    "community",
    "reinvestment",
    "volunteer",
    "time dollars",
    "blockchain",
    "aptos",
    "defi",
  ],
  authors: [{ name: "Homewood Children's Village" }],
  openGraph: {
    title: "The Village - Community Reinvestment Platform",
    description:
      "Transform community participation into verifiable progress on neighborhood projects.",
    type: "website",
    locale: "en_US",
    siteName: "The Village",
  },
  twitter: {
    card: "summary_large_image",
    title: "The Village - Community Reinvestment Platform",
    description:
      "Transform community participation into verifiable progress on neighborhood projects.",
  },
  viewport: {
    width: "device-width",
    initialScale: 1,
    maximumScale: 1,
  },
  themeColor: "#5E3FA3",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}

