; Resource ID of overlay bitmap
;PRINTED_TEXT_BITMAP	equ		800

EFFECT_NONE			equ		0
EFFECT_SIN			equ		1
EFFECT_SPINTAIL		equ		2

SINGLE_CHARACTER	equ		0
MULTI_CHARACTER		equ		1

; LCD text size styles
LCDTEXTSIZE_SMALL	equ		0
LCDTEXTSIZE_BIG 	equ		1

; Button constants
LCDBUTTON_PREVTRACK	equ		20
LCDBUTTON_NEXTTRACK	equ		21
LCDBUTTON_VOLUMEPLUS	equ		22
LCDBUTTON_VOLUMEMIN	equ		23
LCDBUTTON_PLAY		equ		24
LCDBUTTON_STOP		equ		25

; Main timer ID:
MAINTIMERID		equ		3748h

; Used to swap text being displayed
TEXTSWAPTIMER1	equ		3752h

; Used to update a sin value for text effects:
SINTIMERID		equ		3750h

; Used to fade colors in and out
COLORTIMERID	equ		3754h

; Used to tag the timer that tracks when to swap one of the text fields for something else
TEXT1_TIMERID	equ		3760

SCROLLTEXT1_TEXTCHANGE_TIMERID			equ		4000
SCROLLTEXT1_TEXTSCROLLUPDATE_TIMERID	equ		4010

;-----------------------------------------------------------------------------
; Main window width & height
;-----------------------------------------------------------------------------

; NOTE: WINDOW_WIDTH is the width of the actual window. This can be anything
;		as long as it's less than ALIGNED_WIDTH.
;		ALIGNED_WIDTH is the window size rounded up to the next power of 2.
;		This is done so the macros PLOTPIXEL etc can use a shift instead
;		of a mul, which is a lot faster. WIDTH_SHIFT_OFFSET is the power of
;		2 used for ALIGNED_WIDTH
;		(WIDTH_SHIFT_OFFSET = log(ALIGNED_WIDTH) / log(2))
;		WINDOW_HEIGHT can be anything.
;
WINDOW_WIDTH		equ		256 ; Can be anything less than ALIGNED_WIDTH
ALIGNED_WIDTH		equ		256 ; window width aligned to next power of 2
;WINDOW_WIDTH		equ		400 ; Can be anything less than ALIGNED_WIDTH
;ALIGNED_WIDTH		equ		400 ; window width aligned to next power of 2
WIDTH_SHIFT_OFFSET	equ		8   ; = log(ALIGNED_WIDTH) / log(2)
WINDOW_HEIGHT		equ		60
;WINDOW_HEIGHT		equ		300
;ALIGNED_HEIGHT		equ		256


macro comment [args]
{
local useless
macro useless args
}


; The plotpixel macro plots one pixel at (X,Y) with color COLOR onto the
; LCD bitmap. Note that X and Y may not be edx.
;macro PLOTPIXEL X:REQ,Y:REQ,COLOR:REQ {
macro PLOTPIXEL X,Y,COLOR {
	; get Y coordinate
	mov		edx, [Y]

	; shift left WIDTH_SHIFT_OFFSET times,
	; which is the same as multiplying width ALIGNED_WIDTH
	shl		edx, WIDTH_SHIFT_OFFSET

	; add X coordinate
	add		edx, [X]

	; edx is now an offset for the pixel at X,Y. add base offset:
	add		edx, [lpLCDBmp]

	; save color:
	;mov		 byte ptr [edx], COLOR
	;mov		 [edx], COLOR
	mov		 edx, [COLOR]
}

macro darray name,type,[value]
 { common virtual
	    name#.addr type ?
	    name#.itemlen = $-name#.addr
	    name equ name#.addr+name#.itemlen*
	  end virtual
   forward type value }

macro rarray name,type,size
 { virtual
     name#.addr type ?
     name#.itemlen = $-name#.addr
     name equ name#.addr+name#.itemlen*
   end virtual
   if ~ size eq ?
    repeat size
     type ?
    end repeat
   end if }

; Same as PLOTPIXEL, but for a 2x2 pixel block.
; Here too,  X and Y may not be edx.
;PLOT2X2 MACRO X:REQ, Y:REQ, COLOR:REQ
macro PLOT2X2 X,Y,COLOR {
local Temp_Color

	; get Y coordinate
		mov		edx, [Y]
	
	; shift left WIDTH_SHIFT_OFFSET times,
	; which is the same as multiplying width ALIGNED_WIDTH
		shl		edx, WIDTH_SHIFT_OFFSET
	
	; add X coordinate
		add		edx, [X]
	
	; edx is now an offset for the pixel at X,Y. add base offset:
		add		edx, [lpLCDBmp]
	
	; put color at (X,Y) and (X+1,Y)
		;mov		word ptr [edx], COLOR SHL 8 + COLOR
		
		;push ecx
		;mov ecx, COLOR
		;shl ecx, 8
		;add ecx, COLOR
		;mov [edx], WORD ecx
	
		mov [Temp_Color], COLOR
		shl [Temp_Color], 8
		add [Temp_Color], COLOR
		;push [Temp_Color]
		;pop word ptr edx
		push ecx
			mov ecx, dword ptr edx
			mov ecx, Temp_Color
		pop ecx
		
		;mov word ptr [edx], Temp_Color
		
	; put color at (X,Y+1) and (X+1,Y+1):
		;mov		word ptr [edx+ALIGNED_WIDTH], COLOR SHL 8 + COLOR
		mov [Temp_Color], COLOR
		shl [Temp_Color], 8
		add [Temp_Color], COLOR
		push [Temp_Color]
		pop word ptr edx+ALIGNED_WIDTH
}
macro sizeof [objectname] {
      mov eax, sizeof.#objectname
}

; Shadow pixel darkens a specific pixel by adding 7 to it's color index
; (this is a shift from the normal background colors to the shadow background
;  colors). When a pixel is already in shadowed state, it is left unchanged
;SHADOWPIXEL	 MACRO X:REQ, Y:REQ
macro SHADOWPIXEL X,Y
{
	; get Y coordinate
		mov		edx, [Y]

	; shift left WIDTH_SHIFT_OFFSET times,
	; which is the same as multiplying width ALIGNED_WIDTH
		shl		edx, WIDTH_SHIFT_OFFSET

	; add X coordinate
		add		edx, [X]

	; add base offset:
		add		edx, [lpLCDBmp]

	; get pixel
		mov		al, [edx]
		;mov	al, byte ptr edx

	; see if color index > 6 which means it's already a shadow color
		cmp		al, 6
		;ja		@F
		ja exit_macro

	; if not, add 7 to the color index to make it a shadow color
		add		al, 7

	; put new pixel
		mov	[edx], al
	;@@:
	exit_macro:
}

; same as shadowpixel, but for a 2x2 pixel block
; X and Y may not be edx.
;SHADOW2X2	 MACRO X:REQ, Y:REQ
macro SHADOW2X2 X,Y {
	; get Y coordinate
	mov		edx, Y

	; shift left WIDTH_SHIFT_OFFSET times,
	; which is the same as multiplying width ALIGNED_WIDTH
	shl		edx, WIDTH_SHIFT_OFFSET

	; add X coordinate
		add		edx, X
		;push ecx
		;	mov ecx, [X]
		;	add edx, [ecx]
		;pop ecx

	; add base offset:
	add		edx, lpLCDBmp

	; Check for each pixel if it's already a shadow color (index>6). If not,
	; add 7 to make it a shadow color (see also shadowpixel):

	; Shadow (x,y):
	mov		al, [edx]
	;mov	al, byte ptr edx
	cmp		al, 6
	;ja		@F
	ja		LabelA
	add		al, 7
	mov		[edx], al
	;@@:
	LabelA:

	; Shadow (x+1,y):
	;mov		al, [edx+1]
	;mov	al, [edx+1]
	;cmp		al, 6
	;;ja		@F
	;ja 		LabelB
	;add		al, 7
	;mov		[edx+1], al
	;;@@:
	;LabelB:

	; Shadow (x,y+1):
	;mov		al, [edx+ALIGNED_WIDTH]
	;;mov	al, byte ptr [edx+ALIGNED_WIDTH]
	;cmp		al, 6
;	;ja		@F
	;ja		LabelC
	;add		al, 7
	;mov		[edx+ALIGNED_WIDTH], al
;	;@@:
	;LabelC:

	; Shadow (x+1,y+1):
	;mov		al, [edx+ALIGNED_WIDTH+1]
	;cmp		al, 6
;	;ja		@F
	;ja		LabelD
	;add		al, 7
	;mov		[edx+ALIGNED_WIDTH+1], al
;	;@@:
	;LabelD:
}