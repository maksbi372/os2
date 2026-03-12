! ============================================================
! VEZBA.ASM
! Domaci zadatak iz Arhitekture racunara
! Indeks: 0189/2023  =>  b1=9, b2=8, b3=1
! Deo A: b1 mod 4 = 1  => A1
! Deo B: b2 mod 4 = 0  => B0
! Deo V: b3 mod 4 = 1  => V1
! ============================================================

! ============================================================
! inicijalizacija simulacije
! Naredbe ispod postavljaju simulaciono okruzenje:
!   - Test vrednosti koje ce KP1.1 unositi (niz A, 8 elemenata)
!   - Test vrednosti koje ce KP2.1 unositi (niz B, 8 elemenata)
! ============================================================

org x.F300
x.0001 x.0002 x.0003 x.0004 x.0005 x.0006 x.0007 x.0008

org x.F400
x.0011 x.0012 x.0013 x.0014 x.0015 x.0016 x.0017 x.0018

! kraj inicijalizacije

! ============================================================
! Adrese periferija (sve heksadecimalno):
!
!  KP1.1:  Control=F100, Status=F101, Entry=F102, Data=F103
!  KP2.1:  Control=F200, Status=F201, Entry=F202, Data=F203
!
!  DMA1.1: Control=F000, Entry=F002, Count=F004, AR1=F005, AR2=F006
!  DMA1.2: Control=F040, Entry=F042, Count=F044, AR1=F045, AR2=F046
!  DMA1.4: Control=F0C0, Entry=F0C2, Count=F0C4, AR1=F0C5, AR2=F0C6
!
! Format KP kontrolnog registra (bitovi 3..0):
!   bit3=nivo, bit2=start, bit1=enable, bit0=ulaz/izlaz
!
! Format DMA kontrolnog registra (bitovi 7..0):
!   bit7=burst/cycle_stealing, bit6=inc/dec, bit5=update,
!   bit4=mem, bit3=nivo, bit2=start, bit1=enable, bit0=ulaz/izlaz
!
! Deljene promenljive za komunikaciju izmedju glavnog programa
! i prekidne rutine KP1.1 (smeštene na fiksnim adresama):
!   8000h: tekuci pokazivac niza A (inicijalno 5000h)
!   8001h: broj preostalih elemenata niza A (inicijalno 8h)
!   8002h: zastavica "niz A ucitan" (0=nije, 1=jeste)
! ============================================================

! ============================================================
! Prekidna rutina za KP1.1 (ulaz 5 => adresa 0500h)
! Cita jedan element za niz A i smesta ga na tekucu poziciju.
! Kod devetog (laznog) prekida, iskljucuje KP1.1.
! Cuva i restauruje registre r5, r6, r7.
! ============================================================
org x.0500
kp1_1_handler:
    push r5
    push r6
    push r7

    ! Ucitaj preostali brojac za niz A
    ldmem x.8001, r6
    clr r7
    cmp r6, r7
    bneq kp1_1_read

    ! Brojac == 0: lazni prekid koji se nije mogao sprjeciti,
    ! sada iskljucujemo KP1.1
    stmem x.F100, r7       ! upisuje 0 => iskljucuje KP1.1
    jmp kp1_1_exit

kp1_1_read:
    ! Procitaj podatak sa KP1.1 data registra
    ldmem x.F103, r7
    ! Ucitaj tekuci pokazivac niza A
    ldmem x.8000, r5
    ! Sacuvaj podatak na tekucu adresu niza A
    stri [r5], r7
    ! Inkrementiraj pokazivac i sacuvaj
    inc r5
    stmem x.8000, r5
    ! Dekrementiraj brojac i sacuvaj
    dec r6
    stmem x.8001, r6
    ! Provjeri da li je citanje niza A zavrseno
    clr r7
    cmp r6, r7
    bneq kp1_1_exit
    ! Brojac dosao na 0 => postavi zastavicu "niz A ucitan"
    ldimm x.0001, r7
    stmem x.8002, r7

kp1_1_exit:
    pop r7
    pop r6
    pop r5
    rti

! ============================================================
! Rezervisane prekidne rutine (ulazi 4, 2, 3, 1, 0)
! Vracaju se odmah (nije potrebna obrada u ovom zadatku).
! ============================================================

org x.1000
kp1_2_handler:
    rti

org x.1500
kp2_1_handler:
    rti

org x.2000
dma1_1_handler:
    rti

org x.2500
dma1_2_handler:
    rti

org x.3000
dma1_4_handler:
    rti

! ============================================================
! Glavni program (A1): pocinje od adrese 4000h
! ============================================================
org x.4000
main:

    ! ----- Inicijalizacija steka -----
    ldimm x.FFFF, r0
    mvrpr r0, sp           ! SP = FFFFh

    ! ----- Inicijalizacija IV tabele na adresi 0100h -----
    ! (IVTP = 0100h, ulaz i => IVT[i] na adresi 0100h + i)
    !
    ! A1 raspored:
    !   Ulaz 0 => DMA1.4 rutina na 3000h
    !   Ulaz 1 => DMA1.2 rutina na 2500h
    !   Ulaz 2 => KP2.1  rutina na 1500h
    !   Ulaz 3 => DMA1.1 rutina na 2000h
    !   Ulaz 4 => KP1.2  rutina na 1000h
    !   Ulaz 5 => KP1.1  rutina na 0500h

    ldimm x.3000, r0
    stmem x.0100, r0       ! IVT[0] = 3000h  (DMA1.4)
    ldimm x.2500, r0
    stmem x.0101, r0       ! IVT[1] = 2500h  (DMA1.2)
    ldimm x.1500, r0
    stmem x.0102, r0       ! IVT[2] = 1500h  (KP2.1)
    ldimm x.2000, r0
    stmem x.0103, r0       ! IVT[3] = 2000h  (DMA1.1)
    ldimm x.1000, r0
    stmem x.0104, r0       ! IVT[4] = 1000h  (KP1.2)
    ldimm x.0500, r0
    stmem x.0105, r0       ! IVT[5] = 0500h  (KP1.1)

    ! ----- Postavi IVTP = 0100h -----
    ldimm x.0100, r0
    mvrir r0, ivtp

    ! ----- Inicijalizuj deljene promenljive za niz A -----
    ldimm x.5000, r0
    stmem x.8000, r0       ! A_ptr  = 5000h
    ldimm x.0008, r0
    stmem x.8001, r0       ! A_cnt  = 8h
    clr r0
    stmem x.8002, r0       ! A_done = 0

    ! ----- Konfiguriši KP1.1 (prekidni ulaz 5) -----
    ! Ulaz 5 u entry registru
    ldimm x.0005, r0
    stmem x.F102, r0
    ! Kontrola: nivo=1(bit3), start=1(bit2), enable=1(bit1), ulaz=1(bit0)
    !           => 0x000F
    ldimm x.000F, r0
    stmem x.F100, r0

    ! ----- Globalno omoguci prekide -----
    inte

    ! ----- Konfiguriši KP2.1 (polling, ulaz 2 - ali koristimo ispitivanje) -----
    ! Kontrola: nivo=0, start=1(bit2), enable=0, ulaz=1(bit0) => 0x0005
    ldimm x.0005, r0
    stmem x.F200, r0

    ! ----- Inicijalizuj registre za citanje niza B -----
    ldimm x.6000, r1       ! r1 = B_ptr
    ldimm x.0008, r2       ! r2 = B_cnt
    ldimm x.0001, r4       ! r4 = maska 0x0001 (ready bit)

    ! ----- Paralelna petlja: pollingom cita B, prekidi cita A -----
read_loop:
    ! Provjeri da li je B gotov
    clr r3
    cmp r2, r3
    beql b_done

    ! Ispitaj bit spремности KP2.1
    ldmem x.F201, r3       ! r3 = Status registar KP2.1
    and r3, r3, r4         ! r3 = r3 & 0x0001  (Z=1 ako nije spreman)
    beql read_loop         ! nije spreman, ponovi

    ! KP2.1 spreman - ucitaj element niza B
    ldmem x.F203, r3       ! r3 = podatak sa KP2.1
    stri [r1], r3          ! B[i] = r3
    inc r1                 ! B_ptr++
    dec r2                 ! B_cnt--
    jmp read_loop

b_done:
    ! Zaustavi KP2.1
    clr r0
    stmem x.F200, r0

    ! Sacekaj dok i niz A ne bude ucitan (prekidna rutina ce postaviti zastavicu)
wait_a_done:
    ldmem x.8002, r0
    clr r3
    cmp r0, r3
    beql wait_a_done       ! cekaj dok A_done == 0

    ! ----- Oba niza su ucitana -----

    ! Onemogući prekide (vise ne trebaju)
    intd

    ! ============================================================
    ! Deo B0: Pozovi sumAll(A, B, 8h)
    ! Argumenti se guraju na stek u obrnutom redosledu od deklaracije:
    !   push n  (treci)
    !   push arr2 (drugi)
    !   push arr1 (prvi)
    ! Pozivalac cisti stek nakon povratka.
    ! ============================================================
    ldimm x.0008, r0
    push r0                ! gurni n = 8h
    ldimm x.6000, r0
    push r0                ! gurni arr2 = 6000h (niz B)
    ldimm x.5000, r0
    push r0                ! gurni arr1 = 5000h (niz A)
    jsr sumAll

    ! Ciscenje steka: ukloni 3 argumenta (SP += 3)
    mvrpl r1, sp
    ldimm x.0003, r2
    add r1, r1, r2
    mvrpr r1, sp

    ! Rezultat je u R0 - sacuvaj na adresu 9999h
    stmem x.9999, r0

    ! ============================================================
    ! Deo B0: DMA1.4 burst prenos - kopiraj niz B (6000h) u 6100h
    ! mem=1 (mem-to-mem), burst=1, update=1 (AR1 se inkrementira),
    ! inc/dec=0 (inkrement), nivo=0, start=1, enable=0, ulaz=0
    ! Bit mask: burst(7)=1, inc/dec(6)=0, update(5)=1, mem(4)=1,
    !           nivo(3)=0, start(2)=1, enable(1)=0, ulaz(0)=0
    !           => 1011 0100b = 0x00B4
    ! ============================================================
    ldimm x.6000, r0
    stmem x.F0C5, r0       ! DMA1.4 AR1 = 6000h  (izvor: niz B)
    ldimm x.6100, r0
    stmem x.F0C6, r0       ! DMA1.4 AR2 = 6100h  (odrediste)
    ldimm x.0008, r0
    stmem x.F0C4, r0       ! DMA1.4 Count = 8h
    ldimm x.00B4, r0
    stmem x.F0C0, r0       ! Pokreni DMA1.4 (burst blokira dok se ne zavrsi)

    ! ============================================================
    ! Deo V1: DMA1.1 burst izlaz - pošalji niz A (5000h) periferiji
    ! mem=0 (I/O izlaz), burst=1, update=1, inc/dec=0, nivo=0,
    ! start=1, enable=0, ulaz=0 (izlaz: memorija -> periferija)
    ! Bit mask: burst(7)=1, inc/dec(6)=0, update(5)=1, mem(4)=0,
    !           nivo(3)=0, start(2)=1, enable(1)=0, ulaz(0)=0
    !           => 1010 0100b = 0x00A4
    ! ============================================================
    ldimm x.5000, r0
    stmem x.F005, r0       ! DMA1.1 AR1 = 5000h  (izvor: niz A)
    ldimm x.0008, r0
    stmem x.F004, r0       ! DMA1.1 Count = 8h
    ldimm x.00A4, r0
    stmem x.F000, r0       ! Pokreni DMA1.1 (burst blokira dok se ne zavrsi)

    ! ============================================================
    ! Deo V1: DMA1.2 cycle-stealing izlaz - pošalji vrednost sa 9999h
    ! mem=0 (I/O izlaz), burst=0 (cycle-stealing), update=1, inc/dec=0,
    ! nivo=0, start=1, enable=0, ulaz=0
    ! Bit mask: burst(7)=0, inc/dec(6)=0, update(5)=1, mem(4)=0,
    !           nivo(3)=0, start(2)=1, enable(1)=0, ulaz(0)=0
    !           => 0010 0100b = 0x0024
    ! ============================================================
    ldimm x.9999, r0
    stmem x.F045, r0       ! DMA1.2 AR1 = 9999h  (izvor: adresa 9999h)
    ldimm x.0001, r0
    stmem x.F044, r0       ! DMA1.2 Count = 1  (jedan element)
    ldimm x.0024, r0
    stmem x.F040, r0       ! Pokreni DMA1.2 (cycle-stealing)

    halt

! ============================================================
! Potprogram: sumAll(arr1, arr2, n)
!
! Racuna zbir svih elemenata oba niza.
! Vraca rezultat u R0.
!
! Stek pri ulasku u potprogram:
!   [SP+0] = adresa povratka
!   [SP+1] = arr1  (pokazivac na niz 1)
!   [SP+2] = arr2  (pokazivac na niz 2)
!   [SP+3] = n     (broj elemenata)
!
! Cuva i restauruje registre r1, r2, r3, r4, r5.
! ============================================================
sumAll:
    ! Sacuvaj vrednost SP u r5 pre nego sto guramO registre na stek
    ! (koristimo je kao bazni pokazivac za pristup argumentima)
    mvrpl r5, sp           ! r5 = SP (bazni pokazivac za argumente)

    push r1
    push r2
    push r3
    push r4
    push r5                ! sacuvaj r5 (original SP sačuvan u registru ostaje nepromenjen)

    ! Ucitaj argumente koristeci sacuvanu bazu (r5 = stara vrednost SP)
    ldrid [r5]x.1, r1     ! r1 = arr1
    ldrid [r5]x.2, r2     ! r2 = arr2
    ldrid [r5]x.3, r3     ! r3 = n

    clr r0                 ! r0 = suma = 0

sumAll_loop:
    ! Da li je n == 0?
    clr r4
    cmp r3, r4
    beql sumAll_done

    ! suma += arr1[i]
    ldrid [r1]x.0, r4     ! r4 = arr1[i]
    add r0, r0, r4

    ! suma += arr2[i]
    ldrid [r2]x.0, r4     ! r4 = arr2[i]
    add r0, r0, r4

    ! Napreduj pokazivace i smanji brojac
    inc r1                 ! arr1++
    inc r2                 ! arr2++
    dec r3                 ! n--
    jmp sumAll_loop

sumAll_done:
    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    rts
