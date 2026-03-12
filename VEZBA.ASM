! inicijalizacija simulacije
dc x.1, x.9996
dc x.0, x.9998
onkp false, x.1, x.1
onkp false, x.1, x.1
onkp true, x.1, x.1
ondma x.1, x.1
ondma x.1, x.1
ondma x.1, x.1
ondma x.1, x.1
kpreg 1.1, r0, x.1
kpreg 1.1, r1, x.2
kpreg 1.1, r2, x.3
kpreg 1.1, r3, x.4
kpreg 1.1, r4, x.5
kpreg 1.1, r5, x.6
kpreg 1.1, r6, x.7
kpreg 1.1, r7, x.8
kpreg 2.1, r0, x.9
kpreg 2.1, r1, x.a
kpreg 2.1, r2, x.b
kpreg 2.1, r3, x.c
kpreg 2.1, r4, x.d
kpreg 2.1, r5, x.e
kpreg 2.1, r6, x.f
kpreg 2.1, r7, x.10
reg pc, x.4000
reg ivtp, x.4000
reg sp, x.9000
! kraj inicijalizacije


org x.4000

! ===========================================================
! DEO A0: Inicijalizacija IV tabele, IVTP = 0000h
! Ulazi prema tabeli A0:
!   ulaz 0 -> 0500h (KP1.1)
!   ulaz 1 -> 1000h (KP1.2)
!   ulaz 2 -> 1500h (KP2.1)
!   ulaz 3 -> 2000h (DMA1.1)
!   ulaz 4 -> 2500h (DMA1.2)
!   ulaz 5 -> 3000h (DMA1.4)
! ===========================================================

! postavljanje IVTP registra na 0000h
clr r0
mvrir r0, ivtp          ! ivtp = 0000h

! upisivanje adresa rutina u IV tabelu (pocevsi od adrese 0000h)
ldimm x.500, r0
stmem x.0, r0           ! ulaz 0 -> KP1.1 rutina (0500h)
ldimm x.1000, r0
stmem x.1, r0           ! ulaz 1 -> KP1.2 rutina (1000h)
ldimm x.1500, r0
stmem x.2, r0           ! ulaz 2 -> KP2.1 rutina (1500h)
ldimm x.2000, r0
stmem x.3, r0           ! ulaz 3 -> DMA1.1 rutina (2000h)
ldimm x.2500, r0
stmem x.4, r0           ! ulaz 4 -> DMA1.2 rutina (2500h)
ldimm x.3000, r0
stmem x.5, r0           ! ulaz 5 -> DMA1.4 rutina (3000h)

! upisivanje brojeva ulaza u entry registre periferija
clr r0
stmem x.f102, r0        ! KP1.1 entry = 0 (ulaz 0)
ldimm x.1, r0
stmem x.f142, r0        ! KP1.2 entry = 1 (ulaz 1)
ldimm x.2, r0
stmem x.f202, r0        ! KP2.1 entry = 2 (ulaz 2)
ldimm x.3, r0
stmem x.f002, r0        ! DMA1.1 entry = 3 (ulaz 3)
ldimm x.4, r0
stmem x.f042, r0        ! DMA1.2 entry = 4 (ulaz 4)
ldimm x.5, r0
stmem x.f0c2, r0        ! DMA1.4 entry = 5 (ulaz 5)

! ===========================================================
! A0: Niz B ucitati sa KP2.1 mehanizmom prekida
!     r4 = pokazivac u memoriju za niz B (6000h)
!     r5 = brojac + 1 (9 = 8h+1, dekrementira se PRE ucitavanja u ISR)
!     rb = semafor (0 dok nije primljeno svih 8 elemenata)
! ===========================================================
ldimm x.6000, r4        ! r4 pokazivac na pocetak niza B
ldimm x.9, r5           ! r5 = 9 (brojac, 8 podataka + extra)
clr rb                  ! semafor = 0
! Kontrolni registar KP2.1:
!   bit0 (ulaz/izlaz)=1 (ulaz), bit1 (enable)=1, bit2 (nivo)=1, bit3 (start)=1 -> 1111b = Fh
ldimm x.f, r3
stmem x.f200, r3        ! pokretanje KP2.1 sa prekidima

! ===========================================================
! A0: Niz A ucitati sa KP1.1 ispitivanjem bita spremnosti
!     r0 = pokazivac u memoriju za niz A (5000h)
!     r1 = brojac (8h)
! ===========================================================
ldimm x.5000, r0        ! r0 pokazivac na pocetak niza A
ldimm x.8, r1           ! r1 = 8 (broj elemenata)
! Kontrolni registar KP1.1:
!   bit0 (ulaz/izlaz)=1 (ulaz), bit1 (enable)=0, bit2 (nivo)=0, bit3 (start)=1 -> 1001b = 9h
ldimm x.9, r3
stmem x.f100, r3        ! pokretanje KP1.1 (bit spremnosti, bez prekida)

! petlja ispitivanja bita spremnosti KP1.1
ldimm x.1, r3           ! maska za bit ready
loopA:
        ldmem x.f101, r7        ! citanje statusnog registra KP1.1
        and r7, r7, r3          ! izolovanje bita ready
        beql loopA              ! ako nije spreman, cekaj

        ! podatak je spreman
        ldmem x.f103, r7        ! ucitaj podatak iz data registra KP1.1
        stri [r0], r7           ! smesti u memoriju
        inc r0                  ! pomeri pokazivac
        dec r1                  ! smanji brojac
        bneq loopA              ! ponovi dok ima elemenata

! iskljucivanje KP1.1
clr r3
stmem x.f100, r3

! cekanje da ISR KP2.1 postavi semafor (svi elementi niza B primljeni)
ldimm x.1, r3
waitB:
        and rb, rb, r3          ! testiranje semafora
        beql waitB              ! cekaj dok semafor nije 1

! ===========================================================
! DEO B0: poziv sumAll(int* arr1, int* arr2, int n)
!   arr1 = 5000h (niz A), arr2 = 6000h (niz B), n = 8h
!   Parametri se stavljaju na stek u obrnutom redosledu od deklaracije
! ===========================================================
ldimm x.8, r3
push r3                 ! n = 8h
ldimm x.6000, r3
push r3                 ! arr2 = 6000h
ldimm x.5000, r3
push r3                 ! arr1 = 5000h

jsr sumAll              ! poziv potprograma, rezultat se vraca u r0

! ciscenje steka (pozivalac skida argumente)
pop r3
pop r3
pop r3

! cuvanje rezultata na memorijsku lokaciju 9999h
stmem x.9999, r0

! ===========================================================
! B0: Kopiranje niza B (6000h) na 6100h koristeci DMA1.4
!     paketski rezim rada, mem-to-mem transfer
!
! Kontrolni registar DMA1.4 za mem-to-mem paketski:
!   bit0  (start)       = 1
!   bit1  (enable)      = 1
!   bit2  (nivo)        = 1
!   bit3  (ulaz/izlaz)  = 0  (mem->mem, nije ulaz sa periferije)
!   bit4  (mem)         = 1  (mem-to-mem)
!   bit5  (update)      = 1  (azuriranje AR1)
!   bit6  (inc/dec)     = 0  (inkrementiranje)
!   bit7  (burst)       = 1  (paketski)
!   => 1011 0111 = B7h
! ===========================================================
ldimm x.8, r0
stmem x.f0c4, r0        ! COUNT DMA1.4 = 8

ldimm x.6000, r0
stmem x.f0c5, r0        ! AR1 = 6000h (izvor: niz B)

ldimm x.6100, r0
stmem x.f0c6, r0        ! AR2 = 6100h (odrediste)

clr r9                  ! r9 = semafor za DMA1.4 = 0

ldimm x.b7, r0
stmem x.f0c0, r0        ! pokretanje DMA1.4 (paketski, mem-to-mem)

! cekanje da DMA1.4 zavrsi (ISR DMA1.4 ce postaviti r9=1)
ldimm x.1, r1
waitDMA4:
        cmp r1, r9
        bneq waitDMA4

! ===========================================================
! DEO V1:
!   1) Niz A (5000h, 8 elemenata) poslati DMA1.1 u paketskom rezimu
!   2) Vrednost sa 9999h poslati DMA1.2 u rezimu ciklus po ciklus
! ===========================================================

! --- V1 deo 1: Slanje niza A putem DMA1.1 u paketskom rezimu ---
! Kontrolni registar DMA1.1 za izlaz u paketskom rezimu:
!   bit0  (start)       = 1
!   bit1  (enable)      = 1
!   bit2  (nivo)        = 1
!   bit3  (ulaz/izlaz)  = 0  (izlaz: memorija -> periferija)
!   bit4  (mem)         = 0  (nije mem-to-mem)
!   bit5  (update)      = 1  (azuriranje AR1)
!   bit6  (inc/dec)     = 0  (inkrementiranje)
!   bit7  (burst)       = 1  (paketski)
!   => 1010 0111 = A7h

ldimm x.8, r0
stmem x.f004, r0        ! COUNT DMA1.1 = 8

ldimm x.5000, r0
stmem x.f005, r0        ! AR1 DMA1.1 = 5000h (izvor: niz A)

clr r8                  ! r8 = semafor za DMA1.1 = 0

ldimm x.a7, r0
stmem x.f000, r0        ! pokretanje DMA1.1 (paketski izlaz)

! cekanje da DMA1.1 zavrsi
waitDMA1:
        cmp r1, r8
        bneq waitDMA1

! --- V1 deo 2: Slanje vrednosti sa 9999h putem DMA1.2 ciklus po ciklus ---
! Kontrolni registar DMA1.2 za izlaz u rezimu ciklus po ciklus:
!   bit0  (start)       = 1
!   bit1  (enable)      = 1
!   bit2  (nivo)        = 1
!   bit3  (ulaz/izlaz)  = 0  (izlaz: memorija -> periferija)
!   bit4  (mem)         = 0  (nije mem-to-mem)
!   bit5  (update)      = 1  (azuriranje AR1)
!   bit6  (inc/dec)     = 0  (inkrementiranje)
!   bit7  (burst)       = 0  (ciklus po ciklus - cycle stealing)
!   => 0010 0111 = 27h

ldimm x.1, r0
stmem x.f044, r0        ! COUNT DMA1.2 = 1 (jedan podatak)

ldimm x.9999, r0
stmem x.f045, r0        ! AR1 DMA1.2 = 9999h (izvor)

clr r6                  ! r6 = semafor za DMA1.2 = 0

ldimm x.27, r0
stmem x.f040, r0        ! pokretanje DMA1.2 (ciklus po ciklus izlaz)

! cekanje da DMA1.2 zavrsi
waitDMA2:
        cmp r1, r6
        bneq waitDMA2

halt

! ===========================================================
! POTPROGRAM: sumAll(int* arr1, int* arr2, int n)
! Ulazni parametri (na steku, po konvenciji PSasm):
!   [SP+2] = arr1
!   [SP+3] = arr2
!   [SP+4] = n
! Izlaz: r0 = zbir svih elemenata oba niza
!
! Stek u trenutku izvrsavanja potprograma (posle push r4):
!   [SP+0] = sacuvani r4 (frame pointer)
!   [SP+1] = povratna adresa (stavlja jsr)
!   [SP+2] = arr1
!   [SP+3] = arr2
!   [SP+4] = n
! ===========================================================
sumAll:
        push r4
        mvrpl r4, sp            ! r4 = SP (frame pointer)

        push r1
        push r2
        push r3

        ldrid [r4]x.2, r1       ! r1 = arr1
        ldrid [r4]x.3, r2       ! r2 = arr2
        ldrid [r4]x.4, r3       ! r3 = n

        clr r0                  ! r0 = zbir = 0

loopSumAll:
        ldrid [r1]x.0, r4       ! ucitaj arr1[i]
        add r0, r0, r4          ! zbir += arr1[i]
        ldrid [r2]x.0, r4       ! ucitaj arr2[i]
        add r0, r0, r4          ! zbir += arr2[i]
        inc r1                  ! pomeri pokazivac arr1
        inc r2                  ! pomeri pokazivac arr2
        dec r3                  ! smanji brojac
        bneq loopSumAll         ! ponovi dok n != 0

        pop r3
        pop r2
        pop r1
        pop r4
        rts

! ===========================================================
! PREKIDNA RUTINA KP2.1 (ulaz 2, adresa 1500h)
! Koristi globalne registre: r4 (pokazivac), r5 (brojac)
! Semafor: rb (postavi na 1 kada se prime svi elementi)
!
! Logika:
!   - Dekrementiramo r5 pre citanja
!   - Ako r5 != 0: ucitaj podatak i smesti ga u memoriju
!   - Ako r5 == 0: to je 9. prekid (periferija ne moze odmah da se iskljuci)
!                  -> iskljuci KP2.1, postavi semafor
! ===========================================================
org x.1500

        push r2
        dec r5
        bneq ISR_KP21_prenos    ! ako r5 != 0, ima jos podataka za ucitavanje

        ! r5 == 0: primili smo svih 8, ovo je 9. poziv -> iskljuci i postavi semafor
        stmem x.f200, r5        ! iskljucivanje KP2.1 (upisuje 0)
        ldimm x.1, rb           ! postavljanje semafora
        pop r2
        rti

ISR_KP21_prenos:
        ldmem x.f203, r2        ! ucitaj podatak sa KP2.1 (data registar)
        stri [r4], r2           ! smesti u memoriju na [r4]
        inc r4                  ! pomeri pokazivac
        pop r2
        rti

! ===========================================================
! PREKIDNA RUTINA DMA1.4 (ulaz 5, adresa 3000h)
! Postavljanje semafora r9 = 1, iskljucivanje DMA1.4
! ===========================================================
org x.3000

        push r0
        ldimm x.1, r9           ! semafor r9 = 1 (DMA1.4 zavrsio)
        clr r0
        stmem x.f0c0, r0        ! iskljucivanje DMA1.4
        pop r0
        rti

! ===========================================================
! PREKIDNA RUTINA DMA1.1 (ulaz 3, adresa 2000h)
! Postavljanje semafora r8 = 1, iskljucivanje DMA1.1
! ===========================================================
org x.2000

        push r0
        ldimm x.1, r8           ! semafor r8 = 1 (DMA1.1 zavrsio)
        clr r0
        stmem x.f000, r0        ! iskljucivanje DMA1.1
        pop r0
        rti

! ===========================================================
! PREKIDNA RUTINA DMA1.2 (ulaz 4, adresa 2500h)
! Postavljanje semafora r6 = 1, iskljucivanje DMA1.2
! ===========================================================
org x.2500

        push r0
        ldimm x.1, r6           ! semafor r6 = 1 (DMA1.2 zavrsio)
        clr r0
        stmem x.f040, r0        ! iskljucivanje DMA1.2
        pop r0
        rti
