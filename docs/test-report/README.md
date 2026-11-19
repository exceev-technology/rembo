# Test report

Results gathered for the handover package (Testing Protocol). Each run
keeps its date, its device and its raw data next to this page.

## OCR bench on a phone · 19 November 2026

- **Device**: Xiaomi Redmi 25100RA69G, Android 16, debug build.
- **Reader**: on the phone only (Google ML Kit, Latin script, offline), then
  the reading agent (`lib/core/ocr/receipt_parser.dart`). No server reader.
- **Material**: the 30 fictional receipts of `assets/bench/`.
- **Run**: `flutter test integration_test/bench_device_test.dart -d <phone>`.
- **Raw data**: [`ocr-bench-device-2026-11-19.csv`](ocr-bench-device-2026-11-19.csv)
  (1 = field right, 0 = wrong; time per receipt in ms).

| Field | Right |
|---|---|
| Supplier | 83 % |
| ICE | 100 % |
| Date | 83 % |
| Amount with taxes | 80 % |
| VAT | 90 % |
| VAT rate | 100 % |
| Currency | 100 % |
| **All fields** | **91 %** |

| Picture | Clean | Blurred | Faded | Tilted | Crumpled | Shadow | Low resolution | Handwritten |
|---|---|---|---|---|---|---|---|---|
| Fields right | 93 % | 95 % | 93 % | 90 % | 90 % | 90 % | 100 % | 71 % |

Reading takes about 0.2 s per receipt on the phone.

**What goes wrong, and what is done about it**

- Two receipts in Arabic: amounts and dates are read, the supplier is not
  (ML Kit has no Arabic script). They are meant for the server reader.
- Handwritten receipts: half of the dates and supplier names are missed.
  The person types them; the form says what was not read.
- The raw rows of the phone's reader explained most missed amounts: ML Kit
  puts a space after the decimal comma (« 156, 40 », « 450, 00 »), which the
  reading agent did not take for an amount (r11, r18, r20, r29), and « HÔTEL »
  was refused as a supplier name because it contains « tel » (r05). Both are
  corrected and tested on those exact rows (`test/ocr_test.dart`); the rows
  of a tilted ticket are now grouped along the slope of the text (r12).
  A second run on the same phone confirms it (below).
- An amount is never submitted as read: the person checks it, and the
  measures of « Mesures des agents » count what they had to correct.

## OCR bench on a phone, after the corrections · 21 November 2026

Same phone, same 30 receipts, same command. Raw data:
[`ocr-bench-device-2026-11-21.csv`](ocr-bench-device-2026-11-21.csv).

| Field | 19 Nov. | 21 Nov. |
|---|---|---|
| Supplier | 83 % | 90 % |
| ICE | 100 % | 100 % |
| Date | 83 % | 83 % |
| Amount with taxes | 80 % | **100 %** |
| VAT | 90 % | **100 %** |
| VAT rate | 100 % | 100 % |
| Currency | 100 % | 100 % |
| **All fields** | **91 %** | **96 %** |

| Picture | Clean | Blurred | Faded | Tilted | Crumpled | Shadow | Low resolution | Handwritten |
|---|---|---|---|---|---|---|---|---|
| 21 Nov. | 98 % | 95 % | 96 % | 100 % | 95 % | 100 % | 100 % | 81 % |

What is left: five dates (three handwritten receipts, one blurred, one
crumpled) and the supplier of the two Arabic receipts, meant for the
server reader.
