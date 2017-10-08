;===============================================================================
; LCD CD Player - (C) 2000 by Thomas Bleeker [exagone]. http://exagone.cjb.net
;===============================================================================
;
; This program is a basic CD-Player with a nice LCD interface. I didn't finish
; it but the basic functions work and it shows some GDI and MCI stuff. Not all
; functions visible in the main window may work.
;
; Build with MAKE.BAT
;
; Close this program with Alt + F4
;
; Best viewed with tabstop=4 and a good editor with syntax highlighting.
;
; Thomas.
; ska-pig@gmx.net
; http://exagone.cjb.net
;
;.486
;.model flat,stdcall
;option  casemap:none
format PE GUI 4.0
entry start

;include     \masm32\include\windows.inc
;include	 \masm32\include\kernel32.inc
;include	 \masm32\include\winmm.inc
;include	 \masm32\include\user32.inc
;include	 \masm32\include\gdi32.inc
;include		 'windows.inc'
;include 	 'win32a.inc'
include 	 'win32ax.inc'
;include	  'C:\fasm\INCLUDE\Equates\mci.inc'
include 	  'mci.inc'
;include	  'user32.inc'
;include	  'C:\fasm\INCLUDE\MACRO\IF.inc'
include 	 'prog.inc'

;include	 'Defines.inc'
;include		'Globals.inc'
;include	 'LCD.inc'
;include	 'Util_Functions.inc'
;include	 'LCD_DrawText_Functions.inc'

;-----------------------------------------------------------------------------
; Prototypes
;-----------------------------------------------------------------------------
;WinMain				 PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD
;WndProc				 PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD
;CreateLCDColors		 PROTO STDCALL
;CreateLCD				 PROTO	 STDCALL :DWORD
;PseudoRandom			 PROTO	 STDCALL
;DrawLCD			 PROTO	 STDCALL

;DrawChar				 PROTO	 STDCALL :DWORD, :DWORD, :DWORD
;DrawSmallChar			 PROTO	 STDCALL :DWORD, :DWORD, :DWORD
;DrawSineChar			 PROTO	 STDCALL :DWORD, :DWORD, :DWORD
;DrawLCDText				 PROTO	 STDCALL :DWORD, :DWORD, :DWORD, :DWORD
;CheckForButton 		 PROTO	 STDCALL :DWORD, :DWORD
;GetPositionFromString	       PROTO	 STDCALL :DWORD, :DWORD
;GetNextNumberFromTime	       PROTO	 STDCALL

;-----------------------------------------------------------------------------
; Initialized data
;-----------------------------------------------------------------------------
;.data
section '.data' data readable writeable
;AppName	db	"LCD",0
AppName 	TCHAR	'LCD',0
;ClassName	db	"LCD32",0
ClassName	TCHAR	'LCD32',0
; MINE db "MY STRING. GOT HERE SO ITS WORKING SO FAR", 0



;TextPosOffsetMatrix DWORD  0,1,2,3,4,3,2,1,0,-1,-2,-3,-4,-3,-2,-1
;TextPosOffsetMatrix dd  0,4,8,12,16,12,8,4,0,-4,-8,-12,-16,-12,-8,-4
darray TextPosOffsetMatrix,dd,0,4,8,12,16,12,8,4,0,-4,-8,-12,-16,-12,-8,-4

;TextPosOffsetMatrix db  "0","1","2","3","4","3","2","1","0","-1","-2","-3","-4","-3","-2","-1",0
;WindowHeightSizeOffset  equ  200
;WindowWidthSizeOffset	 equ  100
WindowHeightSizeOffset	equ  0
WindowWidthSizeOffset	equ  0




;typedef struct tagBITMAPINFOHEADER{
;  DWORD  biSize
;  LONG   biWidth
;  LONG   biHeight
;  WORD   biPlanes
;  WORD   biBitCount
;  DWORD  biCompression
;  DWORD  biSizeImage
;  LONG   biXPelsPerMeter
;  LONG   biYPelsPerMeter
;  DWORD  biClrUsed
;  DWORD  biClrImportant
;} BITMAPINFOHEADER, *PBITMAPINFOHEADER
; The bitmapinfoheader structure used for the DC the lcd is drawn on
; before it is blitted onto the backbuffer.
; Note that the height property is set to the negated WINDOW_HEIGHT. This
; will cause the bitmap data bits being arranged in top-down order instead
; of the usual down-top order.
; The bitmap used is a 256 color bitmap. A 16-bit bitmap would be enough, but
; then 4 bits per pixel are used which are harder to work with than 8 bits
; per pixel.
;LCDBITMAPINFO	 BITMAPINFOHEADER <SIZEOF BITMAPINFOHEADER,[ALIGNED_WIDTH]+WindowWidthSizeOffset, -[WINDOW_HEIGHT+WindowHeightSizeOffset],1, 8, BI_RGB, 0, 100, 100, 16, 16>
LCDBITMAPINFO	 BITMAPINFOHEADER
;LCDBITMAPINFO	BITMAPINFOHEADER <[sizeof.BITMAPINFOHEADER], [ALIGNED_WIDTH], -[WINDOW_HEIGHT], 1, 8, BI_RGB, 0, 100, 100, 16, 16>




; This is the pallette used. The first 7 colors are the colors that are used
; to paint the green background color of the LCD. The 7 colors after that are
; the same colors as the first 7 ones, but darker for use in shadows. The
; colors are not initialized here, but in the code (CreateLCDColors). This way
; the darkness can be changed. Finally, the last two colors are simply black
; and white. The other 240 colors of the 256 color bitmap are not used (see
; also the note above LCDBITMAPINFO).
LCDBaseColors	db	140, 165, 148, 0  ; --+
				db	148, 165, 140, 0  ;   |
				db	140, 156, 156, 0  ;   |
				db	145, 165, 138, 0  ;   +- 7 LCD background
				db	148, 156, 140, 0  ;   |  colors
				db	142, 156, 140, 0  ;   |
				db	140, 168, 148, 0  ; --+
				db	4 * 7 dup (0)	; ---- Reserved for shadow colors
				db	0,0,0,0       ; ---- Black
				;db	255,0,0,0       ; ---- Blue
				;db	0,0,255,0       ; ---- Red
				db  255,255,255,0	      ; ---- White




;LCD Characters consist of a 6x7 bit pattern like this:
; Character 'A':
;
; 011110  .oooo.
; 100001  o....o
; 100001  o....o
; 111111  oooooo
; 100001  o....o
; 100001  o....o
; 100001  o....o
;
; This pattern is stored row by row, each row of 6 bits gets two extra 0-bits on the
; right, making it a full byte.

; The following table (LCDChars) contains the most used characters. The comment after
; the lines indicate which char is described. (A=10 means that it is the character A,
; at index 10 (0-based) in list)

LCDChars	db		01111000b,10000100b,10001100b,10010100b,10100100b,11000100b,01111000b	;0
			db		00010000b,00110000b,00010000b,00010000b,00010000b,00010000b,00010000b	;1
			db		01111000b,10000100b,00000100b,01111000b,10000000b,10000000b,11111100b	;2
			db		11111000b,00000100b,00000100b,11111000b,00000100b,00000100b,11111000b	;3
			db		10000100b,10000100b,10000100b,11111100b,00000100b,00000100b,00000100b	;4
			db		11111100b,10000000b,10000000b,11111000b,00000100b,10000100b,01111000b	;5
			db		01111000b,10000100b,10000000b,11111000b,10000100b,10000100b,01111000b	;6
			db		01111100b,00001000b,00001000b,00010000b,00010000b,00100000b,00100000b	;7
			db		01111000b,10000100b,10000100b,01111000b,10000100b,10000100b,01111000b	;8
			db		01111000b,10000100b,10000100b,01111100b,00000100b,10000100b,01111000b	;9

			db		01111000b,10000100b,10000100b,11111100b,10000100b,10000100b,10000100b	;A = 10
			db		11111000b,10000100b,10000100b,11111000b,10000100b,10000100b,11111000b	;B
			db		01111100b,10000000b,10000000b,10000000b,10000000b,10000000b,01111100b	;C
			db		11111000b,10000100b,10000100b,10000100b,10000100b,10000100b,11111000b	;D
			db		11111100b,10000000b,10000000b,11111100b,10000000b,10000000b,11111100b	;E
			db		11111100b,10000000b,10000000b,11111100b,10000000b,10000000b,10000000b	;F
			db		01111100b,10000000b,10000000b,10111000b,10000100b,10000100b,01111000b	;G
			db		10000100b,10000100b,10000100b,11111100b,10000100b,10000100b,10000100b	;H
			db		00100000b,00100000b,00100000b,00100000b,00100000b,00100000b,00100000b	;I
			db		00010000b,00010000b,00010000b,00010000b,00010000b,10010000b,01100000b	;J
			db		10001000b,10010000b,10100000b,11000000b,10100000b,10010000b,10001000b	;K
			db		10000000b,10000000b,10000000b,10000000b,10000000b,10000000b,11111100b	;L
			db		11011000b,10101000b,10101000b,10101000b,10101000b,10101000b,10101000b	;M = 22

			db		11000100b,10100100b,10100100b,10010100b,10010100b,10010100b,10001100b	;N = 23
			db		01111000b,10000100b,10000100b,10000100b,10000100b,10000100b,01111000b	;O
			db		11111000b,10000100b,10000100b,11111000b,10000000b,10000000b,10000000b	;P
			db		01111000b,10000100b,10000100b,10000100b,10010100b,10001100b,01111100b	;Q
			db		11111000b,10000100b,10000100b,11111000b,11000000b,10110000b,10001100b	;R
			db		01111000b,10000100b,10000000b,01111000b,00000100b,10000100b,01111000b	;S = 28
			db		11111000b,00100000b,00100000b,00100000b,00100000b,00100000b,00100000b	;T
			db		10000100b,10000100b,10000100b,10000100b,10000100b,10000100b,01111000b	;U
			db		10001000b,10001000b,10001000b,10001000b,01010000b,01010000b,00100000b	;V
			db		10101000b,10101000b,10101000b,10101000b,10101000b,10101000b,01010000b	;W
			db		10001000b,10001000b,01010000b,00100000b,01010000b,10001000b,10001000b	;X
			db		10001000b,10001000b,10001000b,01010000b,00100000b,00100000b,00100000b	;Y
			db		11111100b,00001000b,00010000b,00100000b,01000000b,10000000b,11111100b	;Z = 35

			db		00000000b,00000000b,00000000b,00000000b,00000000b,00110000b,00110000b	;. = 36
			db		00000000b,00000000b,00000000b,00000000b,00110000b,00010000b,00100000b	;, = 37
			db		00000000b,00110000b,00110000b,00000000b,00110000b,00110000b,00000000b	;: = 38
			db		00010000b,00100000b,00100000b,00100000b,00100000b,00100000b,00010000b	;( = 39
			db		00100000b,00010000b,00010000b,00010000b,00010000b,00010000b,00100000b	;) = 40
			db		00000000b,00000000b,11111100b,00000000b,11111100b,00000000b,00000000b	;= = 41
			db		00000000b,00000000b,00000000b,11111100b,00000000b,00000000b,00000000b	;- = 42
			db		01111000b,10000100b,10110100b,11000100b,10110100b,10000100b,01111000b	;© = 43

			db		00011000b,00011000b,00011000b,00011000b,00011000b,00000000b,00011000b	;! = 44
			db		00000000b,00000000b,00000000b,00000000b,00000000b,00000000b,00000000b	;" " = 45

tCollon 	      db		":",0

;Introduction texts
tDemoText0		db "An x86 assembly demo...",0
TextIndex		db 0
TextCount		db 6
;tSmallText1	      DWORD		"StakFallT presents his first Win32 ASM Demo!",0
darray tSmallText1,dd,"S","t","a","k","F","a","l","l","T"," ","p","r","e","s","e","n","t","s"," ","h","i","s"," ","f","i","r","s","t"," ","W","i","n","3","2"," ","A","S","M"," ","D","e","m","o","!"
tDemoText1		dd	 "G","r","e","e","t","i","n","g","s"," ","h","t","t","p",":","/","/","b","o","a","r","d",".","w","i","n","3","2","a","s","m","c","o","m","m","u","n","i","t","y",".","n","e","t","!",0
tDemoText2		dd	 "M","A","J","O","R"," ","t","h","a","n","k","s"," ","t","o"," ","R","o","t","i","c","v",","," ","S","y","n","f","i","r","e",","," ","a","n","d"," ","S","h","o","o",".",".","0"
tDemoText3		db	    "Without you guys this wouldn't have been possible!",0
tDemoText4		db	    "Original LCD CD-Player source copyright (C) 2000 by Thomas Bleeker [exagone]. http://exagone.cjb.net",0
tDemoText5		db	    "Musical composition copyright Minster",0
tmpText 		db	    "TestText",0

tSmallText2		db	"Original CD Player LCD Code © 2000 by Exagone",0
;FileName		 db	     "glimmer.mp3",0
;FileName		 db	     "Downhill_Jump.mp3",0
;FileName		 db	     "The_Adventure_Lights.ogg",0
;FileName		db	"8bp132-04-l-tron-engage.mp3",0
;FileName		db	"c:\\fasm\\asmdemo1\\The_Adventure_Lights.mp3",0
;FileName		db	"The_Adventure_Lights.wav",0
;FileName		db	"The_Adventure_Lights.mp3",0
FileName		db	"Photonic_Journey.mp3",0
PRINTED_TEXT_BITMAP	db "printedtext.bmp",0
;PRINTED_TEXT_BITMAP	db "800",0

DEBUG_Break		db	"Debug: Breakpoint!",0

_error			db	"Error in Msg_Loop!",0
_breakpointmsg	db	"[DEBUG]: Breakpoint hit!",0
_LoadBitmap_BP	db	"[DEBUG]: LoadBitmap Call Trigger!",0
_FindResource_BP	db	"[DEBUG]: FindResource Call Trigger!",0
_SizeofResource_BP	db	"[DEBUG]: SizeofResource Call Trigger!",0
_LoadResource_BP	db	"[DEBUG]: LoadResource Call Trigger!",0

_SelectObject_BP	db	"[DEBUG]: SelectObject Call Trigger!",0
_GetDC_BP				db "[DEBUG]: GetDC Call Trigger!",0
_CreateCompatibleDC_BP	db "[DEBUG]: CreateCompatibleDC Call Trigger!",0
_CreateDIBSection_BP	db "[DEBUG]: CreateDIBSection Call Trigger!",0
;_CreateCompatibleDC_BP db	"[DEBUG]: CreateCompatibleDC Call Trigger!",0
_CreateCompatibleBitmap_BP	db	"[DEBUG]: CreateCompatibleBitmap Call Trigger!",0
_DrawLCD_BP		db	"[DEBUG]: DrawLCD Call Trigger!",0
_ReleaseDC_BP	db	"[DEBUG]: ReleaseDC Call Trigger!",0

_API_ERROR		db	"Failed again...",0

;Letter			db "",0
;Stak			db	5 dup (?)
Stak			db "StakFallT",0
;darray TextTest		dd "Test",0
;darray TextTest, dd, "Test"
;TextTest		db "Test",0

Text1_SelectionIndex	dd 0
	Presents		db "Presents...", 0
	;Stak			db "A",0
	An86Demo		db "an x86 asm demo!", 0
	
	;Greetings		db	 "Greetings board.win32asmcommunity.net / www.asmcommunity.net!",0
	;MajorThanks		db	 "MAJOR thanks to Roticv, Synfire, and Shoo",0
	;Possible		db	 "Without you guys this wouldn't have been possible!",0
	;Credit			db	 "Original LCD CD-Player source copyright (C) 2000 by Thomas Bleeker [exagone]. http://exagone.cjb.net",0

	ScrollText1		db	"Scroll Test",0
	;ScrollText1		db	"Greetings board.win32asmcommunity.net / www.asmcommunity.net!",0
;					db	"MAJOR thanks to Roticv, Synfire, and Shoo"
;					db  "Without you guys this wouldn't have been possible!"
;					db  "Original LCD CD-Player source copyright (C) 2000 by Thomas Bleeker [exagone]. http://exagone.cjb.net"
						
	ScrollText1_DisplayTime_Lengths	db 30
									db 20
									db 28
									db 40
								
Text1_DisplayTime_Length	equ	2

ScrollText1_LastIndex 		dd 3
ScrollText1_LeftX_Min		dd 100
;Remember, that the x pos is based on the first character, to get the last character
;of the text string to finish scrolling off the screen, negatives must be used
	ScrollText1_LeftX_Max	dd 256	; Same as prog.inc - WINDOW_WIDTH

MCI_Error		db	"Error in MCI system, closing device. Please verify sound device is not already in use.",0
;wsprintf format for a 2 digit, 0 padded number
Format2Digits	db	"%02lu",0

;wsprintf format for a TMSF time
FormatTMSF		db	"%lu:%lu:%lu:%lu",0

;wsprintf format for a TMSF time mci seek command
FormatSeekTMSF	db	"seek cdaudio to %lu:%lu:%lu:%lu wait",0

;tOpenMP3		db "open The_Adventure_Lights.mp3 alias The_Adventure_Lights", 0
tOpenMP3		db "open Photonic_Journey.mp3 alias The_Adventure_Lights", 0
tPlayMP3		db "play The_Adventure_Lights", 0
tPlay			db "play", 0
tCloseMP3		db "close The_Adventure_Lights",0

; open cdaudio mci command
tOpenCD 		db	"open cdaudio wait",0

;tSeekCD		 db "seek cdaudio to 1:00:10:00",0

; play cdaudio mci command
tPlayCD 		db	"play cdaudio",0

; stop cdaudio mci command
tStopCD 		db	"stop cdaudio wait",0

; set timeformat mci command
tSetTimeF		db  "set cdaudio time format tmsf wait",0

; get current cdaudio position mci command
tGetPos 		db	"status cdaudio position",0


; Special color indexes in the color palette:
COLORINDEX_BLACK	equ		14
COLORINDEX_WHITE	equ		15
COLORBASE_BACKGROUND	equ		0	;base for background colors (colors 0-6)
COLORBASE_SHADOW	equ		7     ;base for shadow colors (colors 7-13)
BASECOLORCOUNT		equ		7	;7 lcd colors for background & shadow

MID_HEIGHT			equ	10

; The higher this value, the darker the shadow:
SHADOWDARKNESS		equ		40	;color -40 for shadow

; Random seed value to paint the background:
RANDOMSEED		equ		19172991h

; Positions of the various buttons:							      dd
;ButtonVolPlus	 RECT	 <194,13,204,24>
;ButtonVolMin	 RECT	 <181,13,192,24>
;ButtonPrevTrack RECT	 <182,37,194,48>
;ButtonNextTrack RECT	 <195,37,208,48>
;ButtonPlay		 RECT	 <220,12,254,23>
;ButtonStop		 RECT	 <220,24,254,34>

;TextElementIndex dword 01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01h,01
;TextElementIndex dd 01h,02h,03h,04h,05h,06h,07h,08h,09h,10h,11h,12h,13h,14h,15h,16h,01h,02h,03h,04h,05h,06h,07h,08h,09h,10h,11h,12h,13h,14h,15h,16h,01h,02h,03h,04h,05h,06h,07h,08h,09h,10h,11h,12h
darray TextElementIndex, dd, 01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,01,02,03,04,05,06,07,08,09,10,11,12
TextCounter	dd   0
;TempVariable	 dword	 0
tSmallTextCounter dd	      1

;wc WNDCLASS 0,WndProc,0,0,NULL,NULL,NULL,COLOR_BTNFACE+1,NULL,ClassName
wc WNDCLASSEX

;LOCAL	 hwnd:DWORD
msg			MSG

MousePos	POINT

;Holds the hit count for SINTIMERID being fired -- used to offset
;letters displayed for text effects.
	;HitCount	dd	0
	Frame_Counter	dd	0





;-----------------------------------------------------------------------------
; Uninitialized data
;-----------------------------------------------------------------------------
;section '.bss' readable writeable
;.data?
;section '.bss' readable writeable

section '.bss' readable writeable

;hInstance	dd	?

TextTest				dd ?

Letter					db ?

ColorIndex				dd ?

Text1_TimerIimerIndex	dd ?

;Display Count is a running total, each time the timer is fired, and determins if it matches (or is
;greater than the requisite display time length stored in the appropriate element for that scroll
;text.
	ScrollText1_DisplayCount	dd ?
;Index is the element in the display string array that will be displayed
	ScrollText1_Index		dd ?
ScrollText1_XPos		dd ?
ScrollText1_YPos		dd ?

UI_bitmap_info	dd	?
UI_bitmap_size	dd	?
UI_bitmap		dd	?

; Handles of the bitmap & DC for the LCD Display
hLCDDC		dd	?
hLCDBitmap	dd	?
hTextLayer0_DC	dd ?
hTextLayer0Bitmap dd ?	
hScrollingText1_Layer0_DC		dd ?
hScrollingText1_Layer0_Bitmap	dd ?

; Dword that will hold a pointer to the bitmap data in the backbuffer
lpLCDBmp	dd	?
lpTextLayer0Bmp	dd ?
lpScrollingText1_Layer0_Bmp	dd ?

; Random seed variable used in the PseudoRandom procedure.
RandSeed	dd	?

; Handles of DC and bitmap for the backbuffer
hBackDC 	dd	?
hBackBmp	dd	?

; Handles of DC and bitmap for the monochrom overlay
; (the bitmap in the resource file)
hLabelBmp	dd	?
hLabelDC	dd	?
;hTextLayer0_Mono_Bmp	dd ?
;hTextLayer0_Mono_DC		dd ?

ErrorMessage	  db	      ?
BackgroundWidth   db	      ?

; LCD text buffers
tMinuteText		db	5 dup (?)
tSecondsText	db	5 dup (?)
tTrackText		db	5 dup (?)

; - MCI_OPEN_PARAMS Structure (API=mciSendCommand) -
	open_dwCallback			dd ?
	open_wDeviceID			dd ?
	open_lpstrDeviceType	dd ?
	open_lpstrElementName	dd ?
	open_lpstrAlias			dd ?
	
; - MCI_GENERIC_PARMS Structure ( API=mciSendCommand ) -
	generic_dwCallback	dd ?

; - MCI_PLAY_PARMS Structure ( API=mciSendCommand ) -
	play_dwCallback 	dd ?
	play_dwFrom			dd ?
	play_dwTo			dd ?

;hDC				DWORD ?
hwnd				dd ?
ps					PAINTSTRUCT <>

DummyVariable		db ?


hInstance	dd	?

; Handles of the bitmap & DC for the LCD Display
;hLCDBitmap	dd	?
;hLCDDC 	dd	?

; Dword that will hold a pointer to the bitmap data in the backbuffer
;lpLCDBmp	dd	?

; Random seed variable used in the PseudoRandom procedure.
;RandSeed	dd	?

; Handles of DC and bitmap for the backbuffer
;hBackDC dd	?
;hBackBmp	dd	?

; Handles of DC and bitmap for the monochrom overlay
; (the bitmap in the resource file)
;hLabelBmp	dd	?
;hLabelDC	dd	?

;ErrorMessage	  db	      ?
;BackgroundWidth   db	      ?

; LCD text buffers
;tMinuteText		db	5 dup (?)
;tSecondsText		db	5 dup (?)
;tTrackText		db	5 dup (?)

;open_dwCallback	dd ?
;open_wDeviceID 	dd ?
;open_lpstrDeviceType	dd ?
;open_lpstrElementName	dd ?
;open_lpstrAlias	dd ?

; - MCI_GENERIC_PARMS Structure ( API=mciSendCommand ) -
;generic_dwCallback	dd ?

; - MCI_PLAY_PARMS Structure ( API=mciSendCommand ) -
;play_dwCallback	dd ?
;play_dwFrom		dd ?
;play_dwTo		dd ?
;hDC			DWORD ?
;hwnd			dd ?

;DummyVariable		db ?



;-----------------------------------------------------------------------------
; Code
;-----------------------------------------------------------------------------
;.code
;section '.code' code readable writeable
;section '.code' code readable executable
section '.text' code readable executable
start:

	mov	  [tSmallTextCounter], 1

	;invoke  GetModuleHandle,0	;EXE needs to be run as administrator otherwise an Access Denied error occurs (At least on Windows 7), for some reason! EXE also needs to be run in Win XP SP2 compatibility mode otherwise "The specified module could not be found" errors will occur!
    xor eax, eax
    ;GetModuleHandle causes a "The specified module cannot be found" error on anything but Windows 2000 compatibility!
    invoke  GetModuleHandle,eax ;EXE needs to be run as administrator otherwise an Access Denied error occurs (At least on Windows 7), for some reason! EXE also needs to be run in Win XP SP2 compatibility mode otherwise "The specified module could not be found" errors will occur!
    mov     [hInstance],eax
    ;mov     [hInstance],eax
    call ShowLastError
    
    ;invoke  WinMain, [hInstance], NULL, NULL, SW_SHOWNORMAL
    push SW_SHOWNORMAL
    push NULL
    push NULL
    push hInstance
    call WinMain
    
    invoke	ExitProcess, NULL
    
;proc WinMain hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
proc WinMain hInst:DWORD, hPrevInst:DWORD, CmdLine:DWORD, CmdShow:DWORD
	mov [LCDBITMAPINFO.biSize], sizeof.BITMAPINFOHEADER
	mov [LCDBITMAPINFO.biWidth], ALIGNED_WIDTH
	mov [LCDBITMAPINFO.biHeight], -WINDOW_HEIGHT
	mov [LCDBITMAPINFO.biPlanes], 1
	mov [LCDBITMAPINFO.biBitCount], 8
	mov [LCDBITMAPINFO.biCompression], BI_RGB
	mov [LCDBITMAPINFO.biSizeImage], 0
	mov [LCDBITMAPINFO.biXPelsPerMeter], 100
	mov [LCDBITMAPINFO.biYPelsPerMeter], 100
	mov [LCDBITMAPINFO.biClrUsed], 16
	mov [LCDBITMAPINFO.biClrImportant], 16
   
	mov     [wc.cbSize],sizeof.WNDCLASSEX
    mov     [wc.style],   CS_HREDRAW or CS_VREDRAW    
    mov     [wc.lpfnWndProc], WndProc
    mov     [wc.cbClsExtra],NULL
    mov     [wc.cbWndExtra],NULL
    push	[hInst]
    pop		[wc.hInstance]
    mov     [wc.hbrBackground],COLOR_WINDOW
    mov     [wc.lpszMenuName],NULL
    mov     [wc.lpszClassName], ClassName

    invoke  LoadIcon,NULL,IDI_APPLICATION
    	mov     [wc.hIcon],   eax
    	mov     [wc.hIconSm], eax

    invoke  LoadCursor,NULL,IDC_ARROW
    	mov     [wc.hCursor], eax

   	invoke  RegisterClassEx, wc
    call ShowLastError
    
    
    
    ;invoke MessageBox,NULL,_FindResource_BP,NULL,MB_ICONERROR+MB_OK   
    ;invoke FindResource, [wc.hInstance], PRINTED_TEXT_BITMAP, RT_BITMAP
    ;invoke LoadBitmap, [wc.hInstance], 800
    ;invoke LoadBitmap, [wc.hInstance], printed_text
    ;mov [UI_bitmap_info], eax
    ;mov [UI_bitmap], eax
    ;call ShowLastError
       
    ;invoke SizeofResource, [wc.hInstance], UI_bitmap_info
    ;mov [UI_bitmap_size], eax
    ;call ShowLastError
    
    ;invoke LoadResource, [wc.hInstance], [UI_bitmap_info]
	;mov [UI_bitmap], eax
	;call ShowLastError

    
    ;invoke  MessageBox,NULL,_breakpointmsg,NULL,MB_ICONERROR+MB_OK
    ;invoke MessageBox, 0, MINE, MINE, 0
    ; WINDOW_HEIGHT and WINDOW_WIDTH are the dimensions of the display, but the
    ; actual window has borders too. The size of these borders is retrieved with
    ; GetSystemMetrics (multiplied by 2 because there are borders on each side),
    ; and added to the width & height to get the correct size.
    invoke	GetSystemMetrics, SM_CYEDGE
    ;call ShowLastError
    shl 	eax, 1
    add 	eax, WINDOW_HEIGHT
    push	eax
    invoke	GetSystemMetrics, SM_CXEDGE
    ;call ShowLastError
    shl 	eax, 1
    add 	eax, WINDOW_WIDTH
    mov 	ecx, eax
    pop 	edx
    
    ;INVOKE CreateWindowEx,WS_EX_CLIENTEDGE, ADDR ClassName,ADDR AppName,WS_POPUP,400,300,ecx,edx,NULL,NULL,hInst,NULL
    ;invoke CreateWindowEx,WS_EX_CLIENTEDGE,ClassName,AppName,WS_POPUP,400,300,ecx,edx,NULL,NULL,[hInst],NULL
    ;invoke CreateWindowEx,WS_EX_CLIENTEDGE,ClassName,AppName,WS_OVERLAPPEDWINDOW,100, 100, WINDOW_WIDTH, WINDOW_HEIGHT,NULL,NULL,[wc.hInstance],NULL
    ;stdcall CreateWindowEx,WS_EX_CLIENTEDGE,ClassName,AppName,WS_OVERLAPPEDWINDOW,100, 100, WINDOW_WIDTH, WINDOW_HEIGHT,NULL,NULL,[wc.hInstance],NULL
    ;invoke CreateWindowEx,0,ClassName,AppName,WS_VISIBLE+WS_DLGFRAME+WS_SYSMENU,400, 300, ecx, edx,NULL,NULL,[hInstance],NULL
    invoke CreateWindowEx,WS_EX_CLIENTEDGE,ClassName,AppName,WS_POPUP,400, 300, ecx, edx,NULL,NULL,[hInst],NULL
    ;invoke CreateWindowEx,WS_EX_CLIENTEDGE,ClassName,AppName,WS_POPUP,WINDOW_WIDTH, WINDOW_HEIGHT, ecx, edx,NULL,NULL,[hInst],NULL
    mov [hwnd], eax
    invoke ShowWindow,[hwnd],SW_SHOWNORMAL
    invoke UpdateWindow, [hwnd]
	.while TRUE
		invoke GetMessage, msg, [hwnd], 0, 0
		
		.if (eax = 0)
			jmp Exit_Proc
		.endif
		
		invoke TranslateMessage, msg
		invoke DispatchMessage, msg
	.endw

	Error:
		invoke	MessageBox,NULL,_error,NULL,MB_ICONERROR+MB_OK
		
    BreakGetMessage:
		invoke	ExitProcess,[msg.wParam]
		ret

    CloseDevice:
    	call ShowLastError
    	;invoke mciSendCommand,open_wDeviceID,MCI_CLOSE,0,generic_dwCallback
    	invoke MessageBox,0,MCI_Error,AppName,MB_OK
    	invoke ExitProcess,0
    	
    Exit_Proc:
    	mov eax, [msg.wParam]
    	ret
endp

;WndProc proc uses ebx hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
;proc WndProc uses ebx hWnd, uMsg, wParam, lParam
;proc WndProc,hWnd,uMsg,wParam,lParam
proc WndProc uses ebx esi edi, hWnd, uMsg, wParam, lParam
local hDC:DWORD
;ocal Buffer[128]:BYTE

;local MousePos:POINT
;local TempVariable:DWORD
local TempVariable1:DWORD
;local TempVariable2:DWORD
;local TempVariable3:DWORD

local IndexValue:DWORD
local TempX1:DWORD
;local TempX2:DWORD
local TempY1:DWORD
;local TempY2:DWORD

local	rect:RECT

mov eax, [uMsg]
;if [eax] = WM_CREATE
cmp	  [uMsg],WM_CREATE
je	  wmcreate
;cmp	[uMsg],WMNCREATE
;je	wmncreate
cmp	 [uMsg],WM_PAINT
je	 wmpaint
;MM_MCINOTIFY			     equ 3B9h
cmp [uMsg],3B9h
je	 mm_mci_notify
cmp	 [uMsg],WM_NCPAINT
je	 wmpaint
cmp	  [uMsg],WM_TIMER
je	  wmtimer
cmp	  [uMsg],WM_LBUTTONDOWN
je	  wmlbuttondown
;cmp	  [uMsg], WM_NCHITTEST
;je	  wmnchittest
cmp	 [uMsg],WM_DESTROY
je	 wmdestroy

defwndproc:
	;invoke DefWindowProc,[hWnd],[uMsg],[wParam],[lParam]
	invoke	DefWindowProc,[hWnd],[uMsg],[wParam],[lParam]
	jmp	FinishMsgLoop

wmcreate:    	
	; --- Create LCD colors ---
		;invoke  CreateLCDColors
		;stdcall CreateLCDColors

	; --- Create LCD ---
		;invoke CreateLCD, [hWnd]
		;invoke CreateLCD, dword [hWnd]
		;invoke CreateLCD, hWnd
		;push [hWnd]
		;call CreateLCD
		
		call CreateLCDColors
		
		;invoke CreateLCD, [hWnd]
		push [hWnd]
		call CreateLCD
		
		push [hWnd]
		call Create_Main_BackBuffer
		
		push [hWnd]
		call Create_TextLayer0
	  
	  	push [hWnd]
	  	call Create_ScrollingText1_Layer0
	  	
	;-----------------------------------------
    ;MCI_Open parameters
    ;-----------------------------------------
    	mov	  [open_lpstrDeviceType],0h		 ; fill MCI_OPEN_PARAMS structure
    	mov	  [open_lpstrElementName],FileName

	;-----------------------------------------
	;Send Open command with the file
	;-----------------------------------------
    	;invoke	   mciSendCommand,0,MCI_OPEN,MCI_OPEN_ELEMENT,open_dwCallback
    	;MCI_OPEN_ELEMENT		     equ 200h
     	invoke	   mciSendString,tOpenMP3, NULL, 0, [hWnd]
		;call ShowLastError

	;-----------------------------------------	
	;API "mciSendCommandA, MCI_PLAY command begins transmitting output data.
	;-----------------------------------------
    	;MCI_FROM			     equ 4h
    	;invoke	   mciSendCommand,open_wDeviceID,MCI_PLAY,MCI_FROM,play_dwCallback
    	;invoke	   mciSendString,tPlayMP3, NULL, 0, addr play_dwCallback
    	;For some reason, the program chokes on using [hWnd] as the window handle.
    		;invoke	   mciSendString,tPlayMP3, NULL, 0, [hWnd]
    		;so NULL is used instead
    		invoke	   mciSendString,tPlayMP3, NULL, 0, NULL
    	call ShowLastError

	  ;invoke SetTimer, [hWnd], MAINTIMERID, 500, NULL
	  invoke SetTimer, [hWnd], MAINTIMERID, 80, NULL
	  
	  mov [TextIndex], 0
	  mov [Frame_Counter], 1.0
	  invoke SetTimer, [hWnd], SINTIMERID, 5000, NULL
	  ;invoke SetTimer, [hWnd], SINTIMERID, 1000, NULL
	  ;invoke SetTimer, [hWnd], SINTIMERID, 100, NULL
	  
		invoke SetTimer, [hWnd], COLORTIMERID, 5000, NULL
		mov [ColorIndex], 0
	 
	 
	 
	 	mov [Text1_SelectionIndex], 0
		invoke SetTimer, [hWnd], TEXT1_TIMERID, 5000, NULL
		mov [Text1_TimerIimerIndex], 0



		;mov ScrollText1_XPos, [ScrollText1_LeftX_Max]
		push eax
			mov eax, [ScrollText1_LeftX_Max]
			mov [ScrollText1_XPos], eax
		pop eax
		
		mov [ScrollText1_YPos], 10
		
		mov [ScrollText1_Index], 0
		;invoke SetTimer, [hWnd], SCROLLTEXT1_TEXTCHANGE_TIMERID, 30000, NULL
		invoke SetTimer, [hWnd], SCROLLTEXT1_TEXTSCROLLUPDATE_TIMERID, 10, NULL
		;mov [ScrollText1_DisplayCount], 0
		
	  ;call ShowLastError

	  ;push [hWnd]
	  ;call CreateLCD

	; --- Create timer to update the display every 500 ms ---
	  ; invoke  SetTimer, [hWnd], MAINTIMERID, 100, NULL
	  ;invoke   SetTimer, hWnd, TextScroll, 100, NULL
	  ; mov [tSmallTextCounter], 0
	  jmp FinishMsgLoop

wmncreate:
	invoke	DefWindowProc,[hWnd],[uMsg],[wParam],[lParam]
	jmp	FinishMsgLoop
wmtimer:
	; --- display update timer ---
		;.IF		   wParam==MAINTIMERID
		.if [wParam]=MAINTIMERID
			;Invalidate the window to force a repaint
			invoke        InvalidateRect,[hWnd], NULL, FALSE
			jmp FinishMsgLoop
		.elseif [wParam]=COLORTIMERID
			add [ColorIndex], 1
			cmp [ColorIndex], 4
			jge .ResetColorIndex
			jmp FinishMsgLoop
			.ResetColorIndex:
				mov [ColorIndex], 0
				jmp FinishMsgLoop
		.elseif [wParam]=SINTIMERID
			push 10000.00
			push 5.00
			call IncFrameCounter
			;invoke InvalidateRect, [hWnd], NULL, FALSE
			
			;push [lpLCDBmp]
			;push lpTextLayer0Bmp		
			;push [lpTextLayer0Bmp]					;Arg 6
			;push Stak	;DWORD PTR SS:[arg.4]		;Arg 5
			;push MULTI_CHARACTER
			;push LCDTEXTSIZE_SMALL
			;push 10
			;push [Frame_Counter]
			;call DrawLCDText
		
			;DrawChar
			
			
			
			add [TextIndex], 1
			.if	([TextIndex]=7)
				mov [TextIndex], 0
			.endif
			
			jmp FinishMsgLoop
		.elseif [wParam]=TEXT1_TIMERID
			add [Text1_TimerIimerIndex], 1
			cmp [Text1_TimerIimerIndex], Text1_DisplayTime_Length
			jge .IncrementTextSelection
			jmp FinishMsgLoop
			.IncrementTextSelection:
				mov [Text1_TimerIimerIndex], 0			
				add [Text1_SelectionIndex], 1
				cmp [Text1_SelectionIndex], 1
				jg .RollOverToFirstTextSelection
				jmp FinishMsgLoop
				.RollOverToFirstTextSelection:
					mov [Text1_SelectionIndex], 0
					jmp FinishMsgLoop
			;...
		.elseif [wParam]=SCROLLTEXT1_TEXTSCROLLUPDATE_TIMERID
		;.elseif [wParam]=SCROLLTEXT1_TEXTCHANGE_TIMERID
			sub [ScrollText1_XPos], 1
			;cmp [ScrollText1_XPos], ScrollText1_LeftX_Min
			push eax
			mov eax, [ScrollText1_LeftX_Min]
			cmp [ScrollText1_XPos], eax
			pop eax
			jl .RestartScrollText1_FromMaxX
			jmp .ContinueScrollingText
			.RestartScrollText1_FromMaxX:
				;mov [ScrollText1_XPos], ScrollText1_LeftX_Max
				
				;This builds for db type
					;push eax
					;mov al, [ScrollText1_LeftX_Max]
					;mov [ScrollText1], al
					;pop eax
				
				;Just a reminder, as per http://www.flatassembler.net/docs.php?article=manual
				;al and ah are 8 bit registers, NOT 4!!!!!!! Also, ax is 16-bits! and eax is
				;obviously, 32-bit
					push eax
					mov eax, [ScrollText1_LeftX_Max]
					mov [ScrollText1_XPos], eax
					pop eax					
				
				;push si
				;;push al
				;push eax
				;;mov si, BYTE [ScrollText1_LeftX_Max]
				;lodsb
				;mov ScrollText1_XPos, [al]
				;pop eax
				;pop esi
				
				;movsb ScrollText1_XPos, [ScrollText1_LeftX_Max]
				
				;push cx
				;mov cl, [ScrollText1_LeftX_Max]
				;mov ScrollText1_XPos, [cl]
				;pop cx
				
				;Just to ensure fASM doesn't do anything weird due to the next line
				;being a local label
					jmp .ContinueScrollingText
				
			.ContinueScrollingText:
				add [ScrollText1_DisplayCount], 1
				cmp [ScrollText1_DisplayCount], ScrollText1_DisplayTime_Lengths + ScrollText1_Index
				jg .IncrementScrollTextSelection
				jmp FinishMsgLoop
				.IncrementScrollTextSelection:
					mov [ScrollText1_DisplayCount], 0
					add [ScrollText1_Index], 1
					;push ecx, ScrollText1_LastIndex
					;cmp [ScrollText1_LastIndex], [ecx]
					cmp [ScrollText1_Index], ScrollText1_LastIndex
					;pop ecx
					jg .RollOverToFirstScrollTextSelection
					jmp FinishMsgLoop
					.RollOverToFirstScrollTextSelection:
						mov [ScrollText1_Index], 0
						jmp FinishMsgLoop
		.endif

mm_mci_notify:
	invoke	   mciSendString,tCloseMP3, NULL, 0, 0
	jmp FinishMsgLoop
	
;.ELSEIF eax==WM_LBUTTONDOWN
wmlbuttondown:
	; On mousepress, extract X and Y coordinates from lParam:
	  mov		   eax, [lParam]
	  mov		   ecx, eax
	  shr		   ecx, 16	   ; ecx = Y
	  and		   eax, 0ffffh	   ; eax = X

	; Use CheckForButton to see if a button is present at (X,Y)
	  ;invoke  CheckForButton, eax, ecx
	  ;stdcall CheckForButton, eax, ecx

	; The return value is a LCDBUTTON_?? constant:

	xor		eax, eax
	jmp FinishMsgLoop

;.ELSEIF eax==WM_DESTROY
wmdestroy:
	; Kill timer:
	  ;invoke  KillTimer,[hWnd], MAINTIMERID

	; Delete all DCs and buffers:
	  ;invoke  DeleteDC, hBackDC
	  ;invoke  DeleteObject, hBackBmp
	  ;invoke  DeleteDC, hLabelDC
	  ;invoke  DeleteObject, hLabelBmp
	  ;invoke  DeleteDC, hLCDDC
	  ;invoke  DeleteObject, hLCDBitmap

	; Post quit message:
	  invoke  PostQuitMessage, 0
	  xor eax, eax
	  jmp FinishMsgLoop

;.ELSEIF eax==WM_NCHITTEST
wmnchittest:
	; This handler is a little trick to make moving the window easy.

	; First get mouse position in client coordinates:
	  mov	   eax, [lParam]
	  mov	   ecx, eax
	  shr	   ecx, 16		; ecx = Y
	  and	   eax, 0ffffh	; eax = X
	  mov	   [MousePos.x], eax
	  mov	   [MousePos.y], ecx
	  ;invoke  ScreenToClient,[hWnd],[MousePos]  ; HAD []
	  push MousePos
	  push [hWnd]
	  call ScreenToClient

	; Check if mouse is on a button:
	  ;invoke  CheckForButton, [MousePos.x], [MousePos.y]
	  ;push [MousePos.y]
	  ;push [MousePos.x]
	  ;call CheckForButton
	  ;stdcall CheckForButton, [MousePos.x], [MousePos.y]

	;Force-ignore in-window UI button clicks
		xor eax, eax
	
	; If not, return HTCAPTION, which will make windows think you are clicking on
	; the window caption (and thus moving the window)
	;.IF		 eax==0
	.if (eax = 0)
	;cmp eax, 0
	     ;je Set_MouseCoord_Caption
	     ;je Dont_Set_MouseCoord_Caption
	     ;Set_MouseCoord_Caption:
			;From MASM's Windows.inc include files
			;HTCAPTION			     equ 2
			;mov		 eax, HTCAPTION
			mov eax, 2
			;jmp FinishMsgLoop
	     ;Dont_Set_MouseCoord_Caption:
	;.ELSE
	.else
		; Else, do not process the message (so that the button handler is called):
			invoke DefWindowProc,[hWnd],[uMsg],[wParam],[lParam]
			jmp FinishMsgLoop
	;.ENDIF
	.endif

;.ELSEIF eax==WM_PAINT
wmpaint:
	; Start painting:
		invoke BeginPaint, [hWnd], ps
		mov [hDC], eax


	; Draw the LCD on the backbuffer:
		;stdcall DrawLCD
		;push [lpLCDBmp]
		push [lpLCDBmp]
		;call DrawLCD
		stdcall DrawLCD
		
		;push [lpTextLayer0Bmp]
		push [lpLCDBmp]
	   	push EFFECT_SIN
	   	;;push Presents	;DWORD PTR SS:[arg.4]
	   	;push Stak	;DWORD PTR SS:[arg.4]
	   		.if ([TextIndex]=0)
				;push tDemoText0
				push Stak	;DWORD PTR SS:[arg.4]
			.elseif ([TextIndex]=1)
				;push tDemoText1
				push Stak	;DWORD PTR SS:[arg.4]
			.elseif ([TextIndex]=2)
				;push tDemoText2
				push Stak	;DWORD PTR SS:[arg.4]
			.elseif ([TextIndex]=3)
				;push tDemoText3
				push Stak	;DWORD PTR SS:[arg.4]
			.elseif ([TextIndex]=4)
				;push tDemoText4
				push Stak	;DWORD PTR SS:[arg.4]
			.elseif ([TextIndex]=5)
				;push tDemoText5
				push Stak	;DWORD PTR SS:[arg.4]
			;.elseif ([TextIndex]=6)
			;	mov [TextTest], tDemoText6
			.endif
			
		;push [ColorIndex]
	   	;push TextTest
	   	push MULTI_CHARACTER
		push LCDTEXTSIZE_SMALL
		push 30
		push 10
		call DrawLCDText
	   
	   	;push 0				;Color
	   	push [lpLCDBmp]
	   	push EFFECT_NONE
	   	;push Presents	;DWORD PTR SS:[arg.4]
	   	;cmp [Text1_SelectionIndex], 0
	   	.if ([Text1_SelectionIndex]=0)
	   		push Presents
	   	.elseif ([Text1_SelectionIndex]=1)
	   		push An86Demo
	   	.endif

	   	;push Stak	;DWORD PTR SS:[arg.4]
	   	push MULTI_CHARACTER
		push LCDTEXTSIZE_SMALL
		push 50
		push 10
		call DrawLCDText
		
		
		;push [lpLCDBmp]
		;This will be used when our "windowing" technique will be applied for the scrolling effect.
			push [lpScrollingText1_Layer0_Bmp]
		push EFFECT_NONE
		;.if ([ScrollText1_Index
		;push ecx
		;lea ecx, [ScrollText1 + ScrollText1_Index]
		;push ScrollText1 + ScrollText1_Index
		push ScrollText1
		;push dword [ecx]
		;pop ecx
		push MULTI_CHARACTER
		push LCDTEXTSIZE_SMALL
		push 0
		;push 50
		;Rem'ed out now that a "windowing" technique is being used
			;push [ScrollText1_XPos]
		;push [ScrollText1_LeftX_Min]
		push 0
		;push 250
		;push 10
		call DrawLCDText
		
	;From the end of the DrawLCD procedure.
		;Plaster the LCD drawing onto the back buffer hdc
			invoke	BitBlt, [hBackDC],0,0,ALIGNED_WIDTH, WINDOW_HEIGHT, [hLCDDC], 0,0, SRCCOPY
		
		;Next, paste the LCD text ontop of that.
			invoke	BitBlt, [hBackDC],0,0,ALIGNED_WIDTH, WINDOW_HEIGHT, [lpLCDBmp], 0,0, SRCAND
		
		;Now, place the custom text layer(s) on.
			;invoke	BitBlt, [hBackDC],0,0,ALIGNED_WIDTH, WINDOW_HEIGHT, [lpTextLayer0Bmp], 0,0, SRCAND
			;...
			
		;This will be used when our "windowing" technique will be applied for the scrolling effect.
			;invoke BitBlt, [hBackDC], 100, ScrollText1_YPos, 156, 50, [hScrollingText1_Layer0_Bitmap], [ScrollText1_XPos], 0, SRCAND	
			;push ecx
			;	mov ecx, 256
				;Because ScrollText1_XPos is decremented by 1 and it starts at 0, we wind up with
				;a normal range of values in the negative, thus we have to add here to keep the
				;value decrementing, otherwise it'll subtract a negative causing it to increment.
			;		add ecx, [ScrollText1_XPos]
				
				;mov edx, 256
				;sub edx, [ScrollText1_XPos]
				;push edx
				;	mov edx, 256
				;	sub ecx, edx
				;pop edx
				;invoke BitBlt, [hBackDC], 100, [ScrollText1_YPos], 156, 15, [hScrollingText1_Layer0_Bitmap], ecx, 0, SRCAND
				;invoke BitBlt, [hBackDC], 100, [ScrollText1_YPos], 156, 15, [lpScrollingText1_Layer0_Bmp], ecx, 0, SRCAND
				;invoke BitBlt, [hBackDC], 100, 50, 156, 15, [lpScrollingText1_Layer0_Bmp], 0, 0, SRCAND
				invoke BitBlt, [hBackDC], 0, 0,ALIGNED_WIDTH, WINDOW_HEIGHT, [lpScrollingText1_Layer0_Bmp], 0, 0, SRCAND
				;invoke BitBlt, [hBackDC], 0, 0,ALIGNED_WIDTH, WINDOW_HEIGHT, [lpScrollingText1_Layer0_Bmp], 0, 0, SRCCOPY
			;pop ecx
		
		;Finally, place the label drawing on.	
		; --- Blit the monochrome label onto the back buffer ---
			;invoke	BitBlt, [hBackDC],0,0,ALIGNED_WIDTH, WINDOW_HEIGHT, [hLabelDC], 0, 0, SRCAND
		
	;Now, one last step. Paste, the back buffer hDC onto the window's main hDC	
		; Draw the backbuffer onto the main window:
			invoke	BitBlt, [hDC], 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, [hBackDC], 0,0, SRCCOPY
	
	; Stop painting:
	  invoke	 EndPaint, [hWnd], ps
	  
	  
	  jmp FinishMsgLoop
FinishMsgLoop:
	ret
;WndProc endp
endp


;CheckForButton  proc	 dwX:DWORD, dwY:DWORD
proc CheckForButton dwX:DWORD, dwY:DWORD
	; A simple serie of checks to see if a user clicked on a button.
	; Each PtInRect call checks if the click coordinates (dwX, dwY) is
	; in the region of a button. If yes, it returns the appropriate
	; LCDBUTTON_?? value, otherwise it returns 0.

	;invoke  PtInRect, ButtonNextTrack, dwX, dwY
	;.IF		 eax!=0
	;	 mov		 eax, LCDBUTTON_NEXTTRACK
	;	 ret
	;.ENDIF
	;invoke  PtInRect, ADDR ButtonPrevTrack, dwX, dwY
	;.IF		 eax!=0
	;	 mov		 eax, LCDBUTTON_PREVTRACK
	;	 ret
	;.ENDIF
	;invoke  PtInRect, ADDR ButtonPlay, dwX, dwY
	;.IF		 eax!=0
	;	 mov		 eax, LCDBUTTON_PLAY
	;	 ret
	;.ENDIF
	;invoke  PtInRect, ADDR ButtonStop, dwX, dwY
	;.IF		 eax!=0
	;	 mov		 eax, LCDBUTTON_STOP
	;	 ret
	;.ENDIF

;xor		 eax, eax
ret
;CheckForButton  endp
endp



proc Create_Main_BackBuffer uses edi esi ebx, hWnd:DWORD
local	hDC:DWORD

	; Get DC of main window to create compatible DCs:
		invoke  GetDC,[hWnd]
		mov [hDC], eax
		;call ShowLastError
			
	; Create backbuffer:
		invoke  CreateCompatibleDC,[hDC]
		mov     [hBackDC], eax
		;call ShowLastError
		
		;invoke	CreateCompatibleBitmap,[hDC], ALIGNED_WIDTH+WindowWidthSizeOffset, ALIGNED_HEIGHT+WindowHeightSizeOffset
		invoke  CreateCompatibleBitmap,[hDC], ALIGNED_WIDTH, WINDOW_HEIGHT
		mov     [hBackBmp], eax
		;call ShowLastError
		
		invoke  SelectObject, [hBackDC], [hBackBmp]
		;call ShowLastError
		
	; Release main window DC
		invoke  ReleaseDC, [hWnd],[hDC]
		;call ShowLastError
	ret
endp



proc CreateLCD uses edi esi ebx, hWnd:DWORD
local	hDC:DWORD

		; Get DC of main window to create compatible DCs:
			invoke  GetDC,[hWnd]
			mov [hDC], eax
			;call ShowLastError
		
		; Create DC for LCD (background & text):
			invoke  CreateCompatibleDC,[hDC]
			mov [hLCDDC], eax
			;call ShowLastError
			
			; Create a bitmap for the LCD. lpLCDBmp is a dword that will hold a pointer
			; to the raw bitmap data (8-bit per pixel). This pointer is used to draw the
			; LCD.
			; From MASM's Windows.inc include file
			;      DIB_RGB_COLORS			  equ 0
			;      invoke CreateDIBSection,[hDC], LCDBITMAPINFO, DIB_RGB_COLORS, lpLCDBmp, NULL, NULL
				invoke CreateDIBSection,[hDC], LCDBITMAPINFO, 0, lpLCDBmp, NULL, NULL
				mov [hLCDBitmap], eax
				;call ShowLastError
			
		; Select bitmap into DC
	    	invoke  SelectObject, [hLCDDC], [hLCDBitmap]
			;call ShowLastError
			
		; Create overlay label DC & Bitmap (for the bitmap in the resource file)
	    	invoke  CreateCompatibleDC, [hDC]
	    	mov     [hLabelDC], eax
			;call ShowLastError
	
			;invoke	LoadBitmap, [wc.hInstance], PRINTED_TEXT_BITMAP ;Causes "The specified image file did not contain a resource section." error for some reason.
	    	;invoke	LoadBitmap, [wc.hInstance], "printedtext.bmp"	;Causes "The specified image file did not contain a resource section." error for some reason.
	    	;invoke  LoadBitmap, [wc.hInstance], UI_bitmap	;Causes "The specified image file did not contain a resource section." error for some reason.
	    	invoke LoadBitmap, hInstance, 800
	    	mov     [hLabelBmp], eax
			;call ShowLastError
			
	    	invoke  SelectObject, [hLabelDC], [hLabelBmp]
			;call ShowLastError
ret
endp

proc Create_ScrollingText1_Layer0 uses edi esi ebx, hWnd: DWORD
local hDC:DWORD
	; Get DC of main window to create compatible DCs:
		invoke  GetDC, [hWnd]
		mov [hDC], eax
		;call ShowLastError
	
	; Create DC for Text layer
		invoke CreateCompatibleDC, [hDC]
		mov [hScrollingText1_Layer0_DC], eax
		;call ShowLastError
		
		; Create a bitmap for the text layer. lpScrollingText1_Layer0_Bmp is a dword that will hold a pointer
		; to the raw bitmap data (8-bit per pixel). This pointer is used to draw the
		; text layer.
			invoke CreateDIBSection,[hDC], LCDBITMAPINFO, 0, lpScrollingText1_Layer0_Bmp, NULL, NULL
			mov [hScrollingText1_Layer0_Bitmap], eax
			;call ShowLastError
		
	; Select bitmap into DC
    	invoke  SelectObject, [hScrollingText1_Layer0_DC], [hScrollingText1_Layer0_Bitmap]
		;call ShowLastError
		
	; Create overlay label DC & Bitmap (for the bitmap in the resource file)
    	;invoke  CreateCompatibleDC,[hDC]
    	;mov     [hTextLayer0_Mono_DC], eax
		;call ShowLastError
		
	; Release main window DC
		invoke  ReleaseDC, [hWnd],[hDC]
		;call ShowLastError
	
	ret
endp

proc Create_TextLayer0 uses edi esi ebx, hWnd:DWORD
local hDC:DWORD
	; Get DC of main window to create compatible DCs:
		invoke  GetDC, [hWnd]
		mov [hDC], eax
		;call ShowLastError
	
	; Create DC for Text layer
		invoke CreateCompatibleDC, [hDC]
		mov [hTextLayer0_DC], eax
		;call ShowLastError
		
	; Create a bitmap for the text layer. lpTextLayer0Bmp is a dword that will hold a pointer
	; to the raw bitmap data (8-bit per pixel). This pointer is used to draw the
	; text layer.
	invoke CreateDIBSection,[hDC], LCDBITMAPINFO, 0, lpTextLayer0Bmp, NULL, NULL
		mov [hTextLayer0Bitmap], eax
		;call ShowLastError
		
	; Select bitmap into DC
    	invoke  SelectObject, [hTextLayer0_DC], [hTextLayer0Bitmap]
		;call ShowLastError
		
	; Create overlay label DC & Bitmap (for the bitmap in the resource file)
    	;invoke  CreateCompatibleDC,[hDC]
    	;mov     [hTextLayer0_Mono_DC], eax
		;call ShowLastError
		
	; Release main window DC
		invoke  ReleaseDC, [hWnd],[hDC]
		;call ShowLastError
	
	ret
endp

;This routine exists so it can be placed in the SINTIMER callback (in WndProc) block
;and yet still provide decent control over the visual-patterns presented by
;the various graphic effects used by the code
proc IncFrameCounter IncAmount:DWORD, CapAmount:DWORD
local Cap_Amount:DWORD
local Temp_ST0:DWORD
local Temp_ST1:DWORD

	push [CapAmount]	;ARG.2
	pop [Cap_Amount]	;LOCAL.3
	;mov Cap_Amount, [CapAmount]

	fld [Frame_Counter]
		fadd [IncAmount]	
	fld [Cap_Amount]
	
	;Frame_Counter is now ST1
	;(and Cap_Amount is ST0)
	
	;Example usage: http://plantation-productions.com/Webster/www.artofasm.com/Windows/HTML/RealArithmetica2.html
	;(However, not used)
	
	;With no operators, fcom will compare ST0 against ST1
	;(Normal operating procedures is ST0 > ST1)
	fcom
	
	;copy the floating point status register into the AX register
	;(STore Status Word)
		fstsw ax
	;According to: http://stackoverflow.com/questions/24720513/why-take-cmp-ecx-ecx
	;setb will modify AL and seta will modify DL
	;shl ax, 4	;shift al into ah set
	sahf	;Store AH into Flags
	
	;cmp ecx, [Cap_Amount]
	jle postcapcheck
		fstp [Temp_ST0]
		fstp [Temp_ST1]
		fld1
		jmp postcapcheck_2
	;.endif
	postcapcheck:
		fstp [Temp_ST0]
	
	postcapcheck_2:
		fstp [Frame_Counter]

ret
endp

;DrawLCD proc uses edi esi ebx
proc DrawLCD uses edi esi ebx, lpBitmap:DWORD
; --- draw background ---
	; The background is drawn by randomly drawing pixels with color
	; indexes 0-6. Note that this is done every time the LCD is drawn.
	; But because of the fixed randomseed used, the (pseudo) random
	; function will always draw the same pixels and thus always keeping
	; the background the same.
	
	;mov [RandSeed], RANDOMSEED
	
	;push [RANDOMSEED]
	;pop [RandSeed]
	
	mov [RandSeed], 19172991h
	xor ebx, ebx

	;mov ecx, [lpLCDBmp]	;ecx points to raw bitmap data
	mov ecx, [lpBitmap]	;ecx points to raw bitmap data
	xor edi, edi
	
	.while	edi<WINDOW_HEIGHT
		xor		esi, esi
		
		.while	esi<ALIGNED_WIDTH
			call	PseudoRandom
			mov		[ecx+ebx], al		;add random pixel
			
			inc	ebx
			inc	esi
		.endw
		
		inc		edi
	.endw

	ret
endp

proc PseudoRandom uses edx
    mov   eax, 7
    push  edx
	mov edx, [RandSeed]
		imul edx, 08088405h
		inc edx
			mov [RandSeed], edx
			mul edx
			mov eax, edx
	pop edx
ret
endp






; This function simply copies the darker version of the colors 0-6 in
; the palette to colors 7-13. SHADOWDARKNESS determines the darkness
; of the shadow.
;CreateLCDColors proc uses ebx
proc CreateLCDColors uses edx ebx

	xor	ecx, ecx
	mov	edx, LCDBaseColors
	mov	ebx, edx				;ebx points to first background color
	add	edx, COLORBASE_SHADOW*4     ;edx points to first shadow color

	; loop for every color index
		.while	ecx<BASECOLORCOUNT*4
			; read color:
				mov		al, [ebx+ecx]
			
			; darken color:
				.if		al<SHADOWDARKNESS
					xor		al, al
				.else
					sub		al, SHADOWDARKNESS
				.endif
			
			; put darkened color:
				mov		[edx+ecx], al
				
			inc	ecx
		.endw
		
	ret
endp

;DrawLCDText	 proc	 uses esi edi ebx dwX:DWORD, dwY:DWORD, dwSize:DWORD, lpText:DWORD
;proc DrawLCDText dwX, dwY, dwSize, lpText
proc DrawLCDText uses esi edx edi, StartX, StartY, dwSize, MultiLetter, lpText, Effect, lpBitmap
	
; From DrawLCD
;local	hDC:DWORD
;local	Letter:BYTE
local	Letter:DWORD
local	CharacterCounter:DWORD
local	SubCharacterCounter: DWORD
local 	FloatValue:DWORD
local	XPosition:DWORD
local	YPosition:DWORD
local	Frame_Counter_Offset:DWORD
local	Frame_Counter_Scaler:DWORD
local	SinScaler:DWORD
local	Window_Height:DWORD

local One_Hundred_pct:DWORD

local Temp_ST0:DWORD
local Half_Height_Neg:DWORD
local Half_Height_Pos:DWORD
local Half_Height_Factor:DWORD
local Height_Offset:DWORD
local Neg_One: DWORD

	mov [Neg_One], -1
	
	mov [One_Hundred_pct], 100.00
	
	mov [Half_Height_Factor], 2
	
	;fclex = clear floating-point exceptions
		fclex

	;As per http://www.flatassembler.net/docs.php?article=manual
	;fld is used to load values into the FPU register ST(0),
	;fst is then used to copy values out to destinations.
	 
	mov [Window_Height], WINDOW_HEIGHT
	fild [Window_Height]
	;fimul [Half_Height_Factor]
	fidiv [Half_Height_Factor]
	fistp [Half_Height_Pos]
	
	push eax
		push [Half_Height_Pos]
		pop eax
			mul [Neg_One]
			mov [Half_Height_Neg], eax
	pop eax
	
	mov [Frame_Counter_Offset], 1.025
	mov [Frame_Counter_Scaler], 100
	mov [SinScaler], 100.00

	push [StartX]
	pop [XPosition]
	
	push [StartY]
	pop [YPosition]
	
	push esi
	push edi
	push ebx
	push ecx
	push eax

		;load the source string element identified by the ESI
		;register into the EAX register) --
		;http://www.intel.com/content/www/us/en/architecture-and-technology/64-ia-32-architecture-software-developer-manual-325462.html - p.174 of 3463
			;lodsb
		;xor		edi, edi
		;mov [CharacterCounter], 0
	
	
	
	
	; This procedure reads a null-terminated string character for character and
	; looks each char up in the LCDChars table. When found, it displays the character
	; and proceeds to the next. dwX and dwY are the start coordinates (left-top).
	; dwSize can be LCDTEXTSIZE_SMALL or LCDTEXTSIZE_BIG (small or big characters).
	; lpText is the pointer to the string.
	
	mov		esi, [lpText]
	;Set direction flag (for lodsb instruction) to increment
		cld
	
	;edi used to contain the X offset (offset from the last character's
	;position depending on whether the character is big or small) for
	;the current character. The new implementation just modifies a
	;local variable.
		;xor		edi, edi
	
	.while	TRUE
		xor		eax, eax
		
		; get one char:
		;OllyDbg translates lodsb into:
			;MOV AL, BYTE PTR DS:[ESI]
			lodsb
		
		;stop if 0 terminator found:
		;Because the .while TRUE loop sets up an infinite loop with no
		;break coded in, this is our stop gap.
		;See: alt.lang.asm.narkive.com/8HifCtG8/beginner-learning-assembler
		;for the explanation of the (poor) choice of method/technique.
			cmp al, 0
			je break_loop
				
		; --- Map character into LCDChars (ascii -> LCDChars index) ---
		;.if		al>=0x30 && al<=0x39
		;	sub		al, "0"
		.if	al=0x20				;' '
			;mov		al, 43
			;jmp continue_loop
			jmp	next_char
		.elseif al=0x21
			mov		al, 44
			jmp continue_loop
		.elseif al=0x28			;'('
			mov		al, 39
			jmp continue_loop
		.elseif	al=0x29			;')'
			mov		al, 40
			jmp continue_loop
		.elseif	al=0x2C			;','
			mov		al, 37
			jmp continue_loop
		.elseif	al=0x2D			;'-'
			mov		al, 42
			jmp continue_loop
		.elseif	al=0x2E			;'.'
			mov		al, 36
			jmp continue_loop
		.else
			.if al>=0x30
				.if al<=0x39
	         		sub al, "0"
	         		jmp continue_loop
	         	.else
	         		.if al=0x3A			;':'
						mov		al, 38
						jmp continue_loop
					.elseif	al=0x3D		;'='
						mov		al, 41
						jmp continue_loop
					.else
						.if al>=0x41		;'A'
							.if al<=0x5A	;'Z'
								sub		al, ("A"-10)
								jmp continue_loop
							.else
								.if al>=0x61	;'a'
									.if al<=0x7A	;'z'
										;sub al, ("a"-10)
										sub al, ("a"-10)	;Should be 33...
										jmp continue_loop
									.endif
								.endif
							.endif
						.endif
					.endif
				.endif
			.endif
		.endif
		
		;.elseif al=="©"
		;	mov		al, 43
		;else
		
		;if (MultiLetter = MULTI_CHARACTER)
		;	jmp	next_char
		;.else
		;	jmp
		
		continue_loop:
			.if ([Effect] = EFFECT_SIN)
			;Set up the Y position for the character.
				;fclex
				;fldz
				;fld [Frame_Counter]
				
				;Since sin only returns values between -1 and +1, there's
				;no need for the messy/gory details of using scratch
				;memory and fld'ing the value into the FPU stack;
				;otherwise, an fdiv by WINDOW_HEIGHT would need to be
				;performed to tame the values and restrict them back
				;to values that fall within the window's size.
				fld [Frame_Counter]
				fadd [Frame_Counter_Offset]
				fst [Frame_Counter]
					fsin	;Values should already be on float stack (st0) for
							;sin to operate on
					;fmul [SinScaler]
					
				fst [Temp_ST0]
				cmp [Temp_ST0], 0.00000000
				jns	not_neg			;jump if sign flag not set

				negative:
					fimul [Half_Height_Neg]
					jmp post_sign_check
					
				not_neg:
					jmp positive	;Skip if the value is equal to 0
					
					equal_zero:
						;...
						jmp post_sign_check
						
					positive:
						fimul [Half_Height_Pos]
						jmp post_sign_check
				
				post_sign_check:
				;fimul [Window_Height]
				;fmul [SinScaler]	;Move the decimal of the float value to
									;the left by 2 places.
									
				fistp [YPosition]
				;.if ([YPosition] < 0)
					;mul YPosition, [Neg_One]
					;fstp [Temp_ST0]		;Used to dump ST0 register value.
					
				;	fldz				;Reload ST0 register back to 0.0
				;	fistp [YPosition]	;Store this value in YPosition
				;.elseif ([YPosition] > WINDOW_HEIGHT)
				;.elseif ([YPosition] > 50)
				.if ([YPosition] > 50)
					;mov [Window_Height], WINDOW_HEIGHT
					;fldz
					;fild [Window_Height]	;For some unknown reason this loads NANF into st0!
					;fistp [YPosition]
					
					;mov[YPosition], 90
					mov[YPosition], 50	;50 = 32 in hex
				.endif
			.elseif ([Effect] = EFFECT_SPINTAIL)
				
			.endif
										
			push ecx
				;EAX is used because the lodsb op loads a string,
				;pointed to by the esi register, into the eax register
				;Hence, weh have to use ecx here because eax gets
				;clobbered upon entering DrawLCDText by other
				;instructions -- namely the al register which is
				;a subset of the eax register. This is why ecx is
				;preserved one instruction above.
					;mov [ecx], eax	;eax's al contains a copy of 
									;the letter (from the text phrase)
									;read in via lodsb
					mov ecx, eax
					
				;push esi	;preserve the pointer to element of the text string
				
				; --- draw char ---
					.if ([MultiLetter]=MULTI_CHARACTER)
						.if ([dwSize]=LCDTEXTSIZE_SMALL)
							;draw one small char
								;push [Color]
								push [lpBitmap]
								;Not using ecx here because al was
								;modified purposely to get the correct
								;array index/element of LCDCHARS
									push eax		;The actual character
								push [YPosition]
								push [XPosition]
								call DrawSmallChar
						.elseif	([dwSize]=LCDTEXTSIZE_BIG)
							;draw one big char
								;push [Color]
								push [lpBitmap]
								;Not using ecx here because al was
								;modified purposely to get the correct
								;array index/element of LCDCHARS
									push eax		;The actual character
								push [YPosition]
								push [XPosition]
								call DrawChar
						.endif
					.endif
			;pop esi
		
			;.if ([MultiLetter]=MULTI_CHARACTER)
				;inc		esi	;By increasing the pointer of esi by one,
							;the character pointed to in the string is moved ahead
							;to the next character for when the next loop comes through.
			;.endif
		
			pop ecx
		
		next_char:
			;Set the starting plot position off-set from
			;the previous plotted character so it
			;doesn't get drawn on top of.
				;.if ([MultiLetter]=MULTI_CHARACTER)
					.if ([dwSize]=LCDTEXTSIZE_SMALL)
						add [XPosition], 8	;small char takes 8 pixel
					.elseif	([dwSize]=LCDTEXTSIZE_BIG)
						add [XPosition], 22 ;big char takes 22 pixels
					.endif
				;.else
				;	jmp break_loop
				;.endif
	.endw
	
	;@Break:
	break_loop:
		pop eax
		pop ecx
		pop ebx
		pop edi
		pop esi	
		
	ret

;DrawLCDText	 endp
endp


; This procedure draws one character at (dwX, dwY). iChar indentifies the
; character by index in the LCDChars list.
;DrawChar	 proc	 uses esi edi ebx dwX:DWORD, dwY:DWORD, iChar:DWORD
;proc DrawChar	  dwX,dwY,iChar
proc DrawChar uses esi edi ebx, dwX:DWORD, dwY:DWORD, iChar:DWORD, lpBitmap:DWORD
local Temp_Color:DWORD
local	tY:DWORD
local	tX:DWORD

	; Create byte index from character index (multiply by 7, each char takes 7 bytes)
	 	mov		  esi, [iChar]
		shl		  esi, 3	  	;iChar * 8
		sub		  esi, [iChar]	;iChar * 8 - iChar = iChar * 7

	; Add base address of LCDChars array
		add		  esi, LCDChars

	
	; ebx is the row counter:
		xor		  ebx, ebx
		.while ebx<7	; 7 rows for each character
	  		mov	dl, [esi]	;dl holds bits for current row
	  		;mov	dl, byte ptr esi	;dl holds bits for current row
	  		
	  		
	  		; edi is the column counter (each bit is one columnn)
	  			xor edi, edi
	  			mov dl, [esi]
	  			
	  		;Process the bits that make of a single character row's bits first
	  		.while  edi<6			;process 6 bits (6 columns for each char)
	  			;By shifting the bits to the left, we can use the CARRY
	  			;bit to determine if the bit-column is flaged/enabled/on --
	  			;which is then used to determine if the pixel should be plotted
	  			;or not.
					shl		dl, 1			;get next bit
					
				.if CARRY?				;if bit set (carry set), draw pixel:
					; A big char pixel consists of a 2x2 pixel shadow and a 2x2 pixel black
					; block. The pixels are seperated one pixel of each other.
					; So the calculations are:
					; xPixel = column * 3	(each pixel takes 2 pixels and one spacing pixel)
					; yPixel = row * 3		(same here)


					; The shadow is shifted two pixels to the right and to the bottom:
					; xShadow = column * 3 + 2
					; yShadow = row * 3 + 2

					push edx			;save edx

						mov		eax, ebx	;eax = row
						mov		ecx, edi	;ecx = column
						add		ecx, [dwX]	;add X offset
						add		eax, [dwY]	;add Y offset
						mov		[tX], ecx
						mov		[tY], eax
						add		eax, 2		;eax = row + 2
						add		ecx, 2		;ecx = column + 2

						;SHADOW2X2 ecx, eax ;draw 2x2pixel shadow at (ecx,eax)
							; get Y coordinate
								mov		edx, [tY]
							
							; shift left WIDTH_SHIFT_OFFSET times,
							; which is the same as multiplying width ALIGNED_WIDTH
								shl		edx, WIDTH_SHIFT_OFFSET
							
							; add X coordinate
								add		edx, [tX]
							
							; add base offset:
								;add		edx, [lpLCDBmp]
								add			edx, [lpBitmap]
							
							; Check for each pixel if it's already a shadow color (index>6). If not,
							; add 7 to make it a shadow color (see also shadowpixel):
							
							; Shadow (x,y):
								mov		al, [edx]
								cmp		al, 6
								ja		one
								add		al, 7
								mov		[edx], al
							one:
							
							; Shadow (x+1,y):
								mov		al, [edx+1]
								cmp		al, 6
								ja		two
								add		al, 7
								mov		[edx+1], al
							two:
							
							; Shadow (x,y+1):
								mov		al, [edx+ALIGNED_WIDTH]
								cmp		al, 6
								ja		three
								add		al, 7
								mov		[edx+ALIGNED_WIDTH], al
							three:
							
							; Shadow (x+1,y+1):
								mov		al, [edx+ALIGNED_WIDTH+1]
								cmp		al, 6
								ja		four
								add		al, 7
								mov		[edx+ALIGNED_WIDTH+1], al
							four:	
						
						
						
						;PLOT2X2 tX, tY, COLORINDEX_BLACK	;paint 2x2 pixel at (tX,tY)
							; get Y coordinate
								mov		edx, [tY]
							
							; shift left WIDTH_SHIFT_OFFSET times,
							; which is the same as multiplying width ALIGNED_WIDTH
								shl		edx, WIDTH_SHIFT_OFFSET
							
							; add X coordinate
								add		edx, [tX]
							
							; edx is now an offset for the pixel at X,Y. add base offset:
								;add		edx, [lpLCDBmp]
								add			edx, [lpBitmap]
								
							mov		word [edx], 14 SHL 8 + 14
							mov		word [edx+ALIGNED_WIDTH], 7 SHL 8 + 7
							;mov		word [edx+ALIGNED_WIDTH], Color SHL 8 + Color
						
					pop edx 		;pop saved edx
				
				.endif
				
				.if dl=0
					jmp break_innerloop
				.endif
				
				inc edi
			.endw
			
			inc esi
			inc ebx
			jmp outerloop_bottom
			
			break_innerloop:	      
				inc	esi			
				inc	ebx
				jmp outerloop_bottom
				
			outerloop_bottom:
		.endw
		
	ret
endp

;DrawSmallChar	 proc	 uses esi edi ebx dwX:DWORD, dwY:DWORD, iChar:DWORD
;proc DrawSmallChar   dwX,dwY,iChar
proc DrawSmallChar stdcall uses esi edi ebx, dwX:DWORD, dwY:DWORD, iChar:DWORD, lpBitmap:DWORD
local	tX:DWORD
local	tY:DWORD
	; This procedure draws one character at (dwX, dwY). iChar indentifies the
	; character by index in the LCDChars list.
	
	; Create byte index from character index (multiply by 7, each char takes 7 bytes)
	mov		esi, [iChar]
	shl		esi, 3			;iChar * 8
	sub		esi, [iChar]	;iChar * 8 - iChar = iChar * 7
	
	; Add base address of LCDChars array
	add		esi, LCDChars 
	
	; ebx is the row counter:
	xor		ebx, ebx
	.while	ebx<7				; 7 rows for each character
		
		; edi is the column counter (each bit is one columnn)
		xor		edi, edi
		mov		dl, [esi]
		; dl holds bits for current row
		.while	edi<6				;process 6 bits (6 columns for each char)
			shl		dl, 1			;get next bit
			.if CARRY?				;if bit set (carry set), draw pixel:
			
				; A small char pixel consists of a shadow pixel and a black pixel.
				; The calculations are simple here:
				; xPixel = column 
				; yPixel = row 
				
				; The shadow is shifted two pixels to the right and to the bottom:
				; xShadow = column + 2
				; yShadow = row + 2
				
				push	edx			;save edx
				;push	ecx			;save ecx
				
					mov		eax, ebx	;eax = row
					mov		ecx, edi	;ecx = column
					add		ecx, [dwX]	;add X offset
					add		eax, [dwY]	;add Y offset
					mov		[tX], ecx
					mov		[tY], eax
					add		eax, 2		;eax = row + 2
					add		ecx, 2		;ecx = column + 2
				
					; add base offset:
						;add		edx, [lpLCDBmp]
						;add	edx, [lpBitmap]
						mov edx, [lpBitmap]
						
					;SHADOWPIXEL	ecx, eax ;draw shadow pixel at (ecx, eax)
						; get Y coordinate
							;mov		edx, [tY]
							add		edx, [tY]
					
						; shift left WIDTH_SHIFT_OFFSET times,
						; which is the same as multiplying width ALIGNED_WIDTH
							;shl		edx, WIDTH_SHIFT_OFFSET
					
						; add X coordinate
							add		edx, [tX]
					
					
					
						; get pixel
							mov		al, [edx]
							;mov	al, byte ptr edx
					
						; see if color index > 6 which means it's already a shadow color
							.if (al=6)
								; if not, add 7 to the color index to make it a shadow color
									add		al, 7
								
								; put new pixel
									mov	[edx], al
							.endif
							
					;PLOTPIXEL tX, tY, COLORINDEX_BLACK	;paint black pixel at (tX,tY)
						; get Y coordinate
							;mov		edx, [tY]
							mov		edx, [tY]
						
						;This is what separates a shadow-pixel plotting
						;from a regular pixel-lotting.
							; shift left WIDTH_SHIFT_OFFSET times,
							; which is the same as multiplying width ALIGNED_WIDTH
								shl		edx, WIDTH_SHIFT_OFFSET
						
						; add X coordinate
							add		edx, [tX]
							
						; edx is now an offset for the pixel at X,Y. add base offset:
							add edx, [lpBitmap]
						
						; save color:
							;mov		byte [edx], COLOR
							mov		byte [edx], 14	;COLORINDEX_BLACK	equ		14 (the 14th element in the LCDBaseColors array)
							
					;Plot shadow-pixel
						; get Y coordinate
							;mov		edx, [tY]
							mov		edx, [tY]
							
						; shift left WIDTH_SHIFT_OFFSET times,
							; which is the same as multiplying width ALIGNED_WIDTH
							shl		edx, WIDTH_SHIFT_OFFSET
							
						; add X coordinate
							add		edx, [tX]
							
						; add base offset:
							;add		edx, [lpLCDBmp]
							add edx, [lpBitmap]
						
						; get pixel
							mov		al, [edx]

						; see if color index > 6 which means it's already a shadow color
							cmp		al, 6
							ja		.endshadow
				
						; if not, add 7 to the color index to make it a shadow color
							add		al, 7
	
						; put new pixel
							mov		[edx], al
	
						.endshadow:
				;pop		ecx			
				pop		edx			;pop saved edx
					
			.endif
			
			.if	(dl=0)
				jmp break_innerloop
			.endif
			
			inc	edi
		.endw
		
		break_outerloop:
	inc	esi
	inc	ebx
	
	.endw
ret
endp





;proc ShowErrorMessage hWnd,dwError
proc ShowErrorMessage dwError
  local lpBuffer:DWORD
	lea	eax,[lpBuffer]
	invoke	FormatMessage,FORMAT_MESSAGE_ALLOCATE_BUFFER+FORMAT_MESSAGE_FROM_SYSTEM,0,[dwError],LANG_NEUTRAL,eax,0,0
	;invoke MessageBox,[hWnd],[lpBuffer],NULL,MB_ICONERROR+MB_OK
	invoke	MessageBox,NULL,[lpBuffer],NULL,MB_ICONERROR+MB_OK
	invoke	LocalFree,[lpBuffer]
	ret
endp

; VOID ShowLastError(HWND hWnd);

;proc ShowLastError hWnd
proc ShowLastError
	invoke	GetLastError
	cmp eax, NULL
		je NoError
		;stdcall ShowErrorMessage,[hWnd],eax
		stdcall ShowErrorMessage,eax
	NoError:
		ret
endp





data import
;section '.idata' import data readable writeable

library kernel,'KERNEL32.DLL',user,'USER32.DLL',GDI32,'GDI32.DLL',winmm,'WINMM.DLL', msvfw32,'msvfw32.dll'

  import kernel,\
	 GetModuleHandle,'GetModuleHandleA',\
	 CreateFile,'CreateFileA',\
	 ReadFile,'ReadFile',\
	 CloseHandle,'CloseHandle',\
	 FindResource,'FindResourceA',\
	 LoadResource,'LoadResource',\
	 SizeofResource,'SizeofResource',\
	 GetTickCount,'GetTickCount',\
	 GetLastError,'GetLastError',\
	 FormatMessage,'FormatMessageA',\
	 LocalFree,'LocalFree',\
	 ExitProcess,'ExitProcess'

  import user,\
	 BeginPaint,'BeginPaint',\
	 CreateWindowEx,'CreateWindowExA',\
	 DefWindowProc,'DefWindowProcA',\
	 DestroyWindow,'DestroyWindow',\
	 DispatchMessage,'DispatchMessageA',\
	 EndPaint,'EndPaint',\
	 GetClientRect,'GetClientRect',\
	 GetDC,'GetDC',\
	 GetMessage,'GetMessageA',\
	 GetSystemMetrics,'GetSystemMetrics',\
	 InvalidateRect,'InvalidateRect',\
	 KillTimer,'KillTimer',\
	 LoadBitmap,'LoadBitmapA',\
	 LoadCursor,'LoadCursorA',\
	 LoadIcon,'LoadIconA',\
	 MessageBox,'MessageBoxA',\
	 PeekMessage,'PeekMessageA',\
	 PostQuitMessage,'PostQuitMessage',\
	 RegisterClass,'RegisterClassA',\
	 RegisterClassEx,'RegisterClassExA',\
	 ReleaseDC,'ReleaseDC',\
	 ScreenToClient,'ScreenToClient',\
	 SendMessage, 'SendMessageA', \
	 SetCursor,'SetCursor',\
	 SetTimer,'SetTimer',\
	 ShowWindow,'ShowWindow',\
	 TranslateMessage,'TranslateMessage',\
	 UpdateWindow,'UpdateWindow',\
	 WaitMessage,'WaitMessage'

   import winmm,\
	  mciSendCommand, 'mciSendCommandA',\
	  mciSendString, 'mciSendStringA'

   import msvfw32,\
	  MCIWndCreate, 'MCIWndCreateA'

   import GDI32,\
	  BitBlt,'BitBlt',\
	  CreateCompatibleBitmap,'CreateCompatibleBitmap',\
	  CreateCompatibleDC,'CreateCompatibleDC',\
	  CreateDIBSection,'CreateDIBSection',\
	  DeleteDC,'DeleteDC',\
	  DeleteObject,'DeleteObject',\
	  SelectObject,'SelectObject'

end data

section '.rsrc' data readable resource from 'lcd.res'
;section '.rsrc' resource data readable
;	;800 BITMAP "printedtext.bmp"
;	;directory	RT_RCDATA,PRINTED_TEXT_BITMAP
	
;	resource	PRINTED_TEXT_BITMAP,800,LANG_NEUTRAL,UI_bitmap			
;	;fileres		UI_bitmap,'printedtext.bmp'

;section '.rsrc' resource data readable
;IDR_PRINTED_TEXT = 800

;directory	RT_BITMAP,bitmaps

;resource bitmaps,\
;	IDR_PRINTED_TEXT, printed_text
;	;IDR_PRINTED_TEXT, printed_text
	
;bitmap printed_text,'printedtext.bmp'

