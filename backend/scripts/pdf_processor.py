import sys
import os
import json
import time
import argparse
import traceback

# Try to find and configure Tesseract OCR binary
TESSERACT_CANDIDATES = [
    r'C:\Program Files\Tesseract-OCR\tesseract.exe',
    r'C:\Program Files (x86)\Tesseract-OCR\tesseract.exe',
    '/usr/bin/tesseract',
    '/usr/local/bin/tesseract',
    '/opt/homebrew/bin/tesseract',
]

def find_tesseract():
    # Check env var
    env_cmd = os.environ.get('TESSERACT_CMD')
    if env_cmd and os.path.exists(env_cmd):
        return env_cmd
    # Check candidates
    for path in TESSERACT_CANDIDATES:
        if os.path.exists(path):
            return path
    # Check PATH
    import shutil
    which_cmd = shutil.which('tesseract')
    if which_cmd:
        return which_cmd
    return None

def main():
    parser = argparse.ArgumentParser(description="ABUAD Life PDF OCR & Document Extractor")
    parser.add_argument("--input", required=True, help="Path to input PDF file")
    parser.add_argument("--output", required=True, help="Path to output JSON file")
    parser.add_argument("--tesseract-bin", default=None, help="Explicit path to Tesseract binary")
    parser.add_argument("--max-pages", type=int, default=300, help="Maximum pages to process")
    parser.add_argument("--dpi", type=int, default=200, help="DPI for scanned page rendering")
    args = parser.parse_args()

    start_time = time.time()
    input_path = os.path.abspath(args.input)
    output_path = os.path.abspath(args.output)

    result = {
        "success": False,
        "totalPages": 0,
        "processedPages": 0,
        "extractionMethod": "NONE",
        "detectedType": "Unknown",
        "text": "",
        "metadata": {},
        "error": None,
    }

    if not os.path.exists(input_path):
        result["error"] = f"Input file not found: {input_path}"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(result, f)
        sys.exit(1)

    # Initialize OCR engine
    tess_bin = args.tesseract_bin or find_tesseract()
    pytesseract_available = False
    try:
        import pytesseract
        if tess_bin and os.path.exists(tess_bin):
            pytesseract.pytesseract.tesseract_cmd = tess_bin
            pytesseract_available = True
    except Exception as e:
        sys.stderr.write(f"Warning: pytesseract not ready: {e}\n")

    # Import PyMuPDF
    pymupdf_available = False
    try:
        import pymupdf
        pymupdf_available = True
    except Exception:
        try:
            import fitz as pymupdf
            pymupdf_available = True
        except Exception:
            pymupdf_available = False

    # Import PIL / Pillow (optional for scanned image preprocessing)
    pil_available = False
    Image = None
    ImageEnhance = None
    try:
        from PIL import Image as PilImage, ImageEnhance as PilEnhance
        Image = PilImage
        ImageEnhance = PilEnhance
        pil_available = True
    except Exception as e:
        sys.stderr.write(f"Warning: PIL (Pillow) not installed: {e}\n")

    def emit_progress(stage, current_page, total_pages, extra=""):
        pct = int((current_page / max(1, total_pages)) * 100) if total_pages > 0 else 0
        progress_data = {
            "type": "progress",
            "stage": stage,
            "page": current_page,
            "totalPages": total_pages,
            "percent": pct,
            "extra": extra
        }
        print(f"__PROGRESS__{json.dumps(progress_data)}__PROGRESS__", flush=True)

    try:
        if not pymupdf_available:
            raise RuntimeError("PyMuPDF (fitz) is not installed.")

        # Attempt to open the document
        try:
            doc = pymupdf.open(input_path)
        except Exception as open_err:
            result["error"] = f"Failed to open PDF (corrupted or unreadable format): {open_err}"
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(result, f)
            sys.exit(0)

        # Check password protection
        if doc.is_encrypted:
            result["error"] = "PDF is password protected / encrypted. Please remove the password and re-upload."
            doc.close()
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(result, f)
            sys.exit(0)

        total_pages = len(doc)
        if total_pages == 0:
            result["error"] = "PDF is empty (contains 0 pages)."
            doc.close()
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(result, f)
            sys.exit(0)

        pages_to_process = min(total_pages, args.max_pages)
        result["totalPages"] = total_pages
        emit_progress("DETECTING", 0, pages_to_process, "Analyzing document structure...")

        page_texts = []
        digital_pages_count = 0
        ocr_pages_count = 0
        warnings = []

        if total_pages > args.max_pages:
            warnings.append(f"Document contains {total_pages} pages; processing first {args.max_pages} pages to prevent server timeout.")

        for i in range(pages_to_process):
            page_num = i + 1
            page = doc[i]
            emit_progress("EXTRACTING", page_num, pages_to_process, f"Extracting page {page_num} of {pages_to_process}")

            # Try digital text extraction first
            raw_digital_text = page.get_text("text").strip()
            
            # Count alphanumeric characters to verify text quality
            alnum_count = sum(1 for c in raw_digital_text if c.isalnum())
            
            # If page has sufficient readable text (>= 35 alphanumeric characters)
            if alnum_count >= 35:
                digital_pages_count += 1
                clean_page = f"--- Page {page_num} ---\n{raw_digital_text}"
                page_texts.append(clean_page)
            else:
                # Text is empty or insufficient: Scanned page!
                emit_progress("RUNNING_OCR", page_num, pages_to_process, f"Running OCR on scanned page {page_num} of {pages_to_process}")
                
                if not pytesseract_available or not pil_available:
                    # OCR/PIL not available, keep whatever minimal digital text exists
                    if raw_digital_text:
                        page_texts.append(f"--- Page {page_num} ---\n{raw_digital_text}")
                    else:
                        page_texts.append(f"--- Page {page_num} ---\n[Scanned image page - OCR unavailable]")
                    warnings.append(f"Page {page_num} contains scanned content but OCR/imaging engine was unavailable.")
                    continue

                try:
                    # Render page to high-res image
                    pix = page.get_pixmap(dpi=args.dpi)
                    img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
                    
                    # Preprocess image for OCR readability (grayscale + mild contrast enhancement)
                    gray = img.convert('L')
                    enhancer = ImageEnhance.Contrast(gray)
                    processed_img = enhancer.enhance(1.4)

                    # Run Tesseract with automatic page segmentation layout
                    # psm 3: Fully automatic page segmentation (default)
                    # oem 3: Default LSTM + legacy engine
                    custom_config = r'--oem 3 --psm 3'
                    ocr_text = pytesseract.image_to_string(processed_img, config=custom_config).strip()

                    # Free pixmap memory immediately
                    del pix
                    del img
                    del gray
                    del processed_img

                    if len(ocr_text) > 10:
                        ocr_pages_count += 1
                        clean_ocr = f"--- Page {page_num} [OCR] ---\n{ocr_text}"
                        page_texts.append(clean_ocr)
                    else:
                        if raw_digital_text:
                            page_texts.append(f"--- Page {page_num} ---\n{raw_digital_text}")
                        else:
                            page_texts.append(f"--- Page {page_num} ---\n[No readable text detected]")
                            warnings.append(f"Page {page_num}: No readable text detected via digital extraction or OCR.")
                except Exception as ocr_err:
                    sys.stderr.write(f"OCR error on page {page_num}: {ocr_err}\n")
                    warnings.append(f"Page {page_num}: OCR error - {str(ocr_err)}")
                    if raw_digital_text:
                        page_texts.append(f"--- Page {page_num} ---\n{raw_digital_text}")

        doc.close()

        full_extracted_text = "\n\n".join(page_texts).strip()
        word_count = len(full_extracted_text.split())
        char_count = len(full_extracted_text)

        # Determine overall method
        if digital_pages_count > 0 and ocr_pages_count == 0:
            extraction_method = "DIGITAL_TEXT"
            detected_type = "Digital PDF (searchable text)"
        elif ocr_pages_count > 0 and digital_pages_count == 0:
            extraction_method = "OCR"
            detected_type = "Scanned / Image-based PDF (OCR processed)"
        elif digital_pages_count > 0 and ocr_pages_count > 0:
            extraction_method = "HYBRID"
            detected_type = "Hybrid PDF (mixed digital text and scanned pages)"
        else:
            extraction_method = "NONE"
            detected_type = "PDF with no readable text"

        # Quality checks
        if word_count < 15:
            result["success"] = False
            result["error"] = "Extracted text is empty or insufficient to generate study notes or CBT questions."
            warnings.append("Extracted text has fewer than 15 words.")
        else:
            result["success"] = True

        result["totalPages"] = total_pages
        result["processedPages"] = pages_to_process
        result["extractionMethod"] = extraction_method
        result["detectedType"] = detected_type
        result["text"] = full_extracted_text
        result["metadata"] = {
            "wordCount": word_count,
            "charCount": char_count,
            "digitalPages": digital_pages_count,
            "ocrPages": ocr_pages_count,
            "durationMs": int((time.time() - start_time) * 1000),
            "warnings": warnings,
            "tesseractUsed": pytesseract_available and ocr_pages_count > 0,
        }

        emit_progress("COMPLETED", pages_to_process, pages_to_process, "Processing complete")

    except Exception as general_err:
        traceback.print_exc()
        result["success"] = False
        result["error"] = f"PDF processing encountered an error: {general_err}"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    main()
