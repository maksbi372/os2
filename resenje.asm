; ================================================================
; RESENJE - Zadatak iz Operativnih sistema
; ================================================================
;
; Arhitektura: Prilagodjena 16-bitna arhitektura (IKA-stil)
; Napomena: Adrese registara uredjaja su pretpostavljene i treba
;           ih prilagoditi specificnom simulatoru/emulatoru.
;
; Raspored IV tabele (IVTP = 0100h):
;   Ulaz 0: 3000h -> DMA1.4 handler (kopiranje B na 6100h, paketski)
;   Ulaz 1: 2500h -> DMA1.2 handler (slanje 9999h, ciklus-po-ciklus)
;   Ulaz 2: 1500h -> KP2.1 handler  (poliranje, handler postoji radi kompletnosti)
;   Ulaz 3: 2000h -> DMA1.1 handler (slanje niza A, paketski)
;   Ulaz 4: 0500h -> KP1.1 handler  (citanje niza A putem prekida)
;   Ulaz 5: 1000h -> KP1.2 handler  (nekoriscen)
;
; Memorijska mapa:
;   5000h - 500Fh : Niz A (8 elemenata * 2 bajta = 16 bajtova)
;   6000h - 600Fh : Niz B (8 elemenata * 2 bajta = 16 bajtova)
;   6100h - 610Fh : Kopija niza B (DMA1.4 kopira ovde)
;   9999h         : Rezultat sumAll
;   0200h - 020Bh : Pomocne promenljive (pokazivaci, brojaci, zastavice)
; ================================================================

; ----------------------------------------------------------------
; Konstante - adrese uredjaja (prilagoditi specificnom hardveru)
; ----------------------------------------------------------------

; KP1.1 - Tastatura 1, kanal 1 (generise prekid, Ulaz 4)
KP1_1_SR   EQU 0FF10h   ; Status registar (bit0=Spreman, bit1=IE)
KP1_1_DR   EQU 0FF11h   ; Podatkovni registar (procitani podatak)

; KP1.2 - Tastatura 1, kanal 2 (Ulaz 5)
KP1_2_SR   EQU 0FF20h
KP1_2_DR   EQU 0FF21h

; KP2.1 - Tastatura 2, kanal 1 (poliranje, Ulaz 2)
KP2_1_SR   EQU 0FF30h   ; Status registar (bit0=Spreman)
KP2_1_DR   EQU 0FF31h   ; Podatkovni registar

; DMA1.1 - DMA kontroler 1, kanal 1 (Ulaz 3, slanje A, paketski)
DMA1_1_CTRL EQU 0FF40h  ; Kontrolni registar (bit0=START, bit1=BATCH, bit7=DONE)
DMA1_1_ADDR EQU 0FF41h  ; Adresa izvora u memoriji
DMA1_1_CNT  EQU 0FF42h  ; Broj prenosa

; DMA1.2 - DMA kontroler 1, kanal 2 (Ulaz 1, slanje 9999h, ciklus-po-ciklus)
DMA1_2_CTRL EQU 0FF50h
DMA1_2_ADDR EQU 0FF51h
DMA1_2_CNT  EQU 0FF52h

; DMA1.4 - DMA kontroler 1, kanal 4 (Ulaz 0, kopiranje B->6100h, paketski)
DMA1_4_CTRL EQU 0FF70h
DMA1_4_SRC  EQU 0FF71h  ; Izvorna adresa
DMA1_4_DST  EQU 0FF72h  ; Odredisna adresa
DMA1_4_CNT  EQU 0FF73h  ; Broj prenosa

; Bitovi kontrolnog registra DMA
DMA_START        EQU 0001h   ; Bit 0: pokretanje DMA
DMA_BATCH        EQU 0002h   ; Bit 1: paketski rezim (0 = ciklus-po-ciklus)
DMA_DONE         EQU 0080h   ; Bit 7: zavrsetak prenosa
DMA_BATCH_START  EQU 0003h   ; DMA_START | DMA_BATCH (paketski rezim + start)
DMA_CYCLE_START  EQU 0001h   ; DMA_START bez BATCH bita (ciklus-po-ciklus + start)

; Bitovi statusnog registra KP
KP_READY    EQU 0001h   ; Bit 0: uredjaj spreman
KP_IEN      EQU 0002h   ; Bit 1: dozvola prekida
KP_IEN_CLR  EQU 0FFFDh  ; Maska za brisanje IE bita (NOT KP_IEN)

; Ostale konstante
ARRAY_SIZE  EQU 0008h   ; Broj elemenata nizova A i B
RESULT_ADDR EQU 9999h   ; Memorijska lokacija za cuvanje rezultata sumAll

; ----------------------------------------------------------------
; Pomocne promenljive (na adresi 0200h)
; ----------------------------------------------------------------

ORG 0200h
cnt_A      DW 0000h   ; Broj primljenih elemenata niza A
arr_A_ptr  DW 5000h   ; Tekuci pokazivac u niz A
a_done     DW 0000h   ; 1 = niz A je potpuno ucitan

; ================================================================
; IV TABELA (IVTP = 0100h)
; ================================================================

ORG 0100h
    DW 3000h    ; Ulaz 0: DMA1.4 handler
    DW 2500h    ; Ulaz 1: DMA1.2 handler
    DW 1500h    ; Ulaz 2: KP2.1 handler
    DW 2000h    ; Ulaz 3: DMA1.1 handler
    DW 0500h    ; Ulaz 4: KP1.1 handler (citanje niza A)
    DW 1000h    ; Ulaz 5: KP1.2 handler

; ================================================================
; KP1.1 HANDLER - Ulaz 4, adresa 0500h
; Ucitava sledeci element niza A od KP1.1 i smesta ga na 5000h+
; ================================================================

ORG 0500h
KP1_1_HANDLER:
    PUSH R0
    PUSH R1
    PUSH R2

    ; Ucitaj podatak iz KP1.1 podatkovnog registra
    LD R0, [KP1_1_DR]

    ; Ucitaj tekuci pokazivac i smesti element
    LD R1, [arr_A_ptr]
    ST [R1], R0

    ; Pomeri pokazivac na sledeci element (16-bit = 2 bajta)
    INC R1
    INC R1
    ST [arr_A_ptr], R1

    ; Inkrementuj brojac primljenih elemenata
    LD R2, [cnt_A]
    INC R2
    ST [cnt_A], R2

    ; Da li smo primili svih 8 elemenata?
    CMP R2, #ARRAY_SIZE
    JNZ KP1_1_INT_DONE

    ; Svih 8 elemenata primljeno - onemoguci KP1.1 prekid
    LD R0, [KP1_1_SR]
    AND R0, #KP_IEN_CLR         ; Ocisti IE bit (bit 1)
    ST [KP1_1_SR], R0

    ; Postavi zastavicu a_done
    MOV R0, #0001h
    ST [a_done], R0

KP1_1_INT_DONE:
    POP R2
    POP R1
    POP R0
    IRET

; ================================================================
; KP1.2 HANDLER - Ulaz 5, adresa 1000h
; ================================================================

ORG 1000h
KP1_2_HANDLER:
    PUSH R0
    LD R0, [KP1_2_DR]      ; Ocisti prekid citanjem podatka
    POP R0
    IRET

; ================================================================
; KP2.1 HANDLER - Ulaz 2, adresa 1500h
; KP2.1 se koristi poliranjem, ali handler postoji radi IV tabele
; ================================================================

ORG 1500h
KP2_1_HANDLER:
    PUSH R0
    LD R0, [KP2_1_DR]      ; Ocisti prekid citanjem podatka
    POP R0
    IRET

; ================================================================
; DMA1.1 HANDLER - Ulaz 3, adresa 2000h
; Signalizuje kraj slanja niza A uredjaju DMA1.1 u paketskom rezimu
; ================================================================

ORG 2000h
DMA1_1_HANDLER:
    ; DMA1.1 zavrsio slanje niza A - nista posebno ne radimo
    IRET

; ================================================================
; DMA1.2 HANDLER - Ulaz 1, adresa 2500h
; Signalizuje kraj ciklus-po-ciklus prenosa vrednosti sa 9999h
; ================================================================

ORG 2500h
DMA1_2_HANDLER:
    ; DMA1.2 zavrsio prenos - nista posebno ne radimo
    IRET

; ================================================================
; DMA1.4 HANDLER - Ulaz 0, adresa 3000h
; Signalizuje kraj kopiranja niza B na adresu 6100h
; ================================================================

ORG 3000h
DMA1_4_HANDLER:
    ; DMA1.4 zavrsio kopiranje niza B -> 6100h - nista ne radimo
    IRET

; ================================================================
; FUNKCIJA sumAll - adresa 4E00h
; int sumAll(int* arr1, int* arr2, int n)
; Sabira sve elemente oba niza, rezultat vraca u R0.
;
; Pozivna konvencija (parametri guraju desno-na-levo / cdecl):
;   PUSH #n       <- guramo poslednji
;   PUSH #arr2
;   PUSH #arr1    <- guramo prvi
;   CALL SUMALL
;   ADD SP, #6    <- ciscenje steka (3 * 2 bajta)
;
; Izgled steka pri ulasku u funkciju:
;   [SP+0] = povratna adresa (2 bajta)
;   [SP+2] = arr1
;   [SP+4] = arr2
;   [SP+6] = n
; ================================================================

ORG 4E00h
SUMALL:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5

    ; Ucitaj parametre sa steka
    ; (5 PUSH-eva pomerila SP za 10; povratna adresa jos 2 => SP+12 = arr1)
    LD R1, [SP+12]     ; R1 = arr1 (pokazivac na niz A)
    LD R2, [SP+14]     ; R2 = arr2 (pokazivac na niz B)
    LD R3, [SP+16]     ; R3 = n (broj elemenata)

    MOV R0, #0000h     ; R0 = akumulator (rezultat = 0)

SUMALL_LOOP:
    CMP R3, #0000h
    JZ SUMALL_END

    ; Dodaj element iz arr1
    LD R4, [R1]
    ADD R0, R4
    INC R1
    INC R1             ; 16-bit element = 2 bajta

    ; Dodaj element iz arr2
    LD R5, [R2]
    ADD R0, R5
    INC R2
    INC R2

    DEC R3
    JMP SUMALL_LOOP

SUMALL_END:
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ================================================================
; GLAVNI PROGRAM - adresa 4000h
; ================================================================

ORG 4000h
START:

    ; ============================================================
    ; A1: Inicijalizacija IVTP registra
    ; ============================================================
    MOV IVTP, #0100h

    ; ============================================================
    ; A1: Inicijalizacija pomocnih promenljivih
    ; ============================================================
    MOV R0, #5000h
    ST [arr_A_ptr], R0      ; arr_A_ptr = 5000h (pocetak niza A)

    MOV R0, #0000h
    ST [cnt_A], R0          ; cnt_A = 0
    ST [a_done], R0         ; a_done = 0

    ; ============================================================
    ; A1: Omoguci prekid za KP1.1 (IE bit)
    ; ============================================================
    LD R0, [KP1_1_SR]
    OR R0, #KP_IEN          ; Postavi IE bit
    ST [KP1_1_SR], R0

    ; ============================================================
    ; A1: Globalno omoguci prekide
    ; ============================================================
    EI

    ; ============================================================
    ; A1: Uporedan prijem:
    ;     - Niz A se ucitava putem KP1.1 interrupt handlera (0500h)
    ;     - Niz B se ucitava poliranjem KP2.1 (ispod)
    ; ============================================================

    ; Citaj niz B poliranjem KP2.1 (8 elemenata, smestaj na 6000h)
    MOV R1, #6000h          ; Pokazivac na niz B
    MOV R3, #ARRAY_SIZE     ; Brojac = 8

READ_B_LOOP:
    CMP R3, #0000h
    JZ READ_B_DONE

    ; Poliranje bita spremnosti KP2.1 (bit 0 statusnog registra)
POLL_KP2_1:
    LD R0, [KP2_1_SR]
    AND R0, #KP_READY
    JZ POLL_KP2_1           ; Nije spreman, nastavi cekati

    ; Procitaj podatak i smesti u niz B
    LD R0, [KP2_1_DR]
    ST [R1], R0

    INC R1
    INC R1                  ; Sledeci element (16-bit = 2 bajta)
    DEC R3
    JMP READ_B_LOOP

READ_B_DONE:

    ; Sacekaj da se niz A potpuno ucita putem KP1.1 prekida
WAIT_A_DONE:
    LD R0, [a_done]
    CMP R0, #0001h
    JNZ WAIT_A_DONE

    ; ============================================================
    ; B0: Pozovi sumAll(5000h, 6000h, 8)
    ;     Parametri se guraju desno-na-levo (cdecl konvencija)
    ; ============================================================
    PUSH #ARRAY_SIZE        ; n = 8
    PUSH #6000h             ; arr2 = pocetna adresa niza B
    PUSH #5000h             ; arr1 = pocetna adresa niza A
    CALL SUMALL
    ADD SP, #0006h          ; Ocisti stek (3 parametra * 2 bajta)

    ; Sacuvaj rezultat (u R0) na memorijsku lokaciju 9999h
    ST [RESULT_ADDR], R0

    ; ============================================================
    ; B0: Kopiraj niz B (6000h -> 6100h) koristenjem DMA1.4
    ;     u paketskom (batch) rezimu rada
    ; ============================================================
    DI                          ; Onemoguci prekide tokom DMA konfiguracije

    MOV R0, #6000h
    ST [DMA1_4_SRC], R0         ; Izvorna adresa = 6000h (niz B)

    MOV R0, #6100h
    ST [DMA1_4_DST], R0         ; Odredisna adresa = 6100h

    MOV R0, #ARRAY_SIZE
    ST [DMA1_4_CNT], R0         ; Broj elemenata = 8

    ; Postavi rezim (paketski) i pokreni DMA1.4
    MOV R0, #DMA_BATCH_START
    ST [DMA1_4_CTRL], R0

    EI                          ; Ponovo omoguci prekide

    ; Cekaj kraj DMA1.4 (poliranjem DONE bita ili prekidom)
WAIT_DMA14_DONE:
    LD R0, [DMA1_4_CTRL]
    AND R0, #DMA_DONE
    JZ WAIT_DMA14_DONE

    ; ============================================================
    ; V1 (C1): Posalji niz A uredjaju DMA1.1 u paketskom rezimu
    ; ============================================================
    DI

    MOV R0, #5000h
    ST [DMA1_1_ADDR], R0        ; Izvorna adresa = 5000h (niz A)

    MOV R0, #ARRAY_SIZE
    ST [DMA1_1_CNT], R0         ; Broj elemenata = 8

    ; Paketski rezim, pokretanje DMA1.1
    MOV R0, #DMA_BATCH_START
    ST [DMA1_1_CTRL], R0

    EI

    ; Cekaj kraj DMA1.1
WAIT_DMA11_DONE:
    LD R0, [DMA1_1_CTRL]
    AND R0, #DMA_DONE
    JZ WAIT_DMA11_DONE

    ; ============================================================
    ; V1 (C1): Posalji vrednost sa 9999h uredjaju DMA1.2
    ;          u rezimu ciklus-po-ciklus
    ; ============================================================
    DI

    MOV R0, #RESULT_ADDR
    ST [DMA1_2_ADDR], R0        ; Adresa izvora = 9999h

    MOV R0, #0001h
    ST [DMA1_2_CNT], R0         ; Broj prenosa = 1 (jedna vrednost)

    ; Ciklus-po-ciklus rezim (bez BATCH bita), pokretanje DMA1.2
    MOV R0, #DMA_CYCLE_START
    ST [DMA1_2_CTRL], R0

    EI

    ; Cekaj kraj DMA1.2
WAIT_DMA12_DONE:
    LD R0, [DMA1_2_CTRL]
    AND R0, #DMA_DONE
    JZ WAIT_DMA12_DONE

    ; ============================================================
    ; Kraj programa
    ; ============================================================
    HALT
