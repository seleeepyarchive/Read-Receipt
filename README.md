# Read-Receipt
Read Receipt for KOReader (English version)

A receipt-style "reading ticket" for KOReader, showing the current book, progress, reading time, and today's summary. Works as a menu item and as a sleep screen.

Credits
Original design and patch by w8. (Xiaohongshu/Rednote) / wongyx04-create (GitHub): https://github.com/wongyx04-create/readreceipt
English translation and layout changes by Selena, shared with the original creator's permission. Please support the original creator.

What was changed from the original
All text translated to English
Courier Prime font instead of the original fonts
The page you were reading shows behind the ticket (settings at the top of the file)
Ticket aligned to the left (TICKET_ALIGN)

Install
Copy 2-read-receipt.lua to koreader/patches/ (Kobo: .adds/koreader/patches/).
Download Courier Prime (free, Google Fonts) and copy CourierPrime-Regular.ttf to koreader/fonts/ (Kobo: .adds/koreader/fonts/).
Restart KOReader. Open a book, then menu > Tools > READ RECEIPT. For the sleep screen: Settings > Screen > Sleep screen > Wallpaper > READ RECEIPT.

The Statistics plugin must be enabled for the reading-time figures.

Settings (top of the .lua file)
BACKGROUND = "page", "cover", or "white"
BACKGROUND_FADE = 0 to 1
PAPER_WHITE = true or false
TICKET_ALIGN = "left", "center", or "right"
Fonts

The original used commercial FZ fonts, which are not included here. Courier Prime is open-licensed (SIL OFL); download it from Google Fonts.
