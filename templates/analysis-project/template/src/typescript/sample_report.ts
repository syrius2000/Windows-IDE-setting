/**
 * Sample TypeScript PowerPoint / Slidev generator script
 */

import PptxGenJS from "pptxgenjs";
import * as path from "path";
import * as fs from "fs";

async function generateSlideDeck(): Promise<void> {
  const pptx = new PptxGenJS();
  pptx.layout = "LAYOUT_16x9";

  // Title Slide
  const slide1 = pptx.addSlide();
  slide1.addText("RWD Analysis Report", {
    x: 1.0,
    y: 2.0,
    w: 11.3,
    h: 1.5,
    fontSize: 32,
    bold: true,
    color: "003366",
  });
  slide1.addText("Osaka University Biostatistics & RWD Platform", {
    x: 1.0,
    y: 3.8,
    w: 11.3,
    h: 1.0,
    fontSize: 18,
    color: "666666",
  });

  // Table Slide
  const slide2 = pptx.addSlide();
  slide2.addText("Cohort Summary (Synthetic Validation)", {
    x: 0.5,
    y: 0.5,
    w: 12.0,
    h: 0.8,
    fontSize: 22,
    bold: true,
    color: "003366",
  });

  const tableRows = [
    [
      { text: "Arm", options: { bold: true, fill: "F0F4F8" } },
      { text: "Patients", options: { bold: true, fill: "F0F4F8" } },
      { text: "Mean Age", options: { bold: true, fill: "F0F4F8" } },
      { text: "Events", options: { bold: true, fill: "F0F4F8" } },
    ],
    [{ text: "Active" }, { text: "67" }, { text: "61.2" }, { text: "16" }],
    [{ text: "Control" }, { text: "33" }, { text: "59.8" }, { text: "9" }],
  ];

  slide2.addTable(tableRows, {
    x: 0.5,
    y: 1.5,
    w: 12.0,
    h: 3.0,
    fontSize: 14,
    border: { pt: 1, color: "CCCCCC" },
  });

  const outDir = path.resolve(__dirname, "../../outputs/private");
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }
  const outFile = path.join(outDir, "sample_presentation.pptx");
  await pptx.writeFile({ fileName: outFile });
  console.log(`[INFO] Generated editable PowerPoint at: ${outFile}`);
}

generateSlideDeck().catch(console.error);
