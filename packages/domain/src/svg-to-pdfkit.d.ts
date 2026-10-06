declare module "svg-to-pdfkit" {
  const SVGtoPDF: (
    doc: PDFKit.PDFDocument,
    svg: string,
    x: number,
    y: number,
    optionen?: { width?: number; height?: number },
  ) => void;
  export default SVGtoPDF;
}
