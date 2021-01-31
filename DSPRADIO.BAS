REM DSP Radio Control for MachiKania type M
REM Radio IC DSP6959
REM D/A Converter MCP4922,MCP4911
REM Use following Class Library
REM   Character LCD Class    CHRLCD.BAS
REM   Real Time Clock Class  RTC.BAS
REM   Button Class           BUTTON.BAS

USECLASS RTC
USECLASS CHRLCD
USECLASS BUTTON

USEVAR PBAND,PTUNE,PNAME,PFREQ,PNUM
USEVAR BNUMBR,BNAME,BNUM
DIM PBAND(29),PTUNE(29),PNAME(29),PFREQ(29)
DIM BNUMBR(18),BNAME(18)

REM -- Read Band Number & Name --
BNUM=0:REM Number of bands
RESTORE BLIST
DO
 A=READ():IF A<0 THEN BREAK
 BNUMBR(BNUM)=A
 A$=READ$():BNAME(BNUM)=A
 BNUM=BNUM+1
LOOP WHILE BNUM<19

REM -- Read Program Stations List --
PNUM=0:REM Number of radio stations
RESTORE PLIST
DO
 A=READ():IF A<0 THEN BREAK
 PBAND(PNUM)=A
 IF A=0 THEN
  PFREQ(PNUM)=READ()
  PTUNE(PNUM)=PFREQ(PNUM)*9523/100000-6523
 ELSEIF A=1 THEN
  PFREQ(PNUM)=READ()
  PTUNE(PNUM)=PFREQ(PNUM)*2-884
 ELSE
  PTUNE(PNUM)=READ()
 ENDIF
 A$=READ$():PNAME(PNUM)=A
 PNUM=PNUM+1
LOOP WHILE PNUM<30

USEVAR RT
RT=NEW(RTC,14,15,16,18)

USEVAR LCD
LCD=NEW(CHRLCD,0,1,2,3,4,5)
RESTORE FONT
FOR I=0 TO 7
 LCD.SETCG(I,READ(),READ())
NEXT

USEVAR BT
BT=NEW(BUTTON)

REM Set B7 port as input
D=IN(7)
POKE16 $BF886154,$0080:REM PULL UP OFF

USEVAR BAND,VOL,TUNE,MODE,PRGSEL,CHGFLG,SECOND

MODE=0
BAND=17
VOL=7
TUNE=0
PRGSEL=0
CHGFLG=1
SYSTEM 200,0:REM Video off

REM ---------------------------------
REM            Main Loop
REM ---------------------------------
REM MODE 0:Select Programmed Radio Stations
REM MODE 1:Tune Manually

DO
 WAIT 1   :REM 1/60 seconds wait
 BT.RD()  :REM Read buttons

 IF MODE=0 THEN
  GOSUB SELPRG
 ELSEIF MODE=1 THEN
  GOSUB MNTUNE
 ENDIF

LOOP

REM ---------------------------------
REM Select Programmed Radio Stations
REM ---------------------------------

REM Left,Right  Select Stations
REM Up,Down     Change Volume
REM Fire (1s)   Set Clock
REM Start       Manual Tuning mode

LABEL SELPRG
 VAR P,V
 IF CHGFLG THEN
  CHGFLG=0
  BAND=PBAND(PRGSEL)
  TUNE=PTUNE(PRGSEL)
  GOSUB DSPPRG
  GOSUB PRADIO
 ENDIF
 GOSUB DSPTIM

 P=PRGSEL:V=VOL
 IF BT.BLT2 THEN PRGSEL=PRGSEL-1
 IF BT.BRT2 THEN PRGSEL=PRGSEL+1
 PRGSEL=(PRGSEL+PNUM)%PNUM
 IF BT.BDN2!=0 AND VOL>0 THEN VOL=VOL-1
 IF BT.BUP2!=0 AND VOL<16 THEN VOL=VOL+1
 IF BT.BST3 THEN MODE=1:LCD.CLR()
 IF BT.BFRCT>=60 THEN
  LCD.CLR()
  GOSUB SETCLK
  P=-1
 ENDIF
 CHGFLG=(PRGSEL!=P)+(VOL!=V)+(MODE!=0)
RETURN

REM -- Display Programmed Stations Mode --
LABEL DSPPRG
 VAR S
 LCD.CUR(0,0)
 S=PNAME(PRGSEL)
 LCD.PUTSTR(S$)

 LCD.CUR(0,1)
 S=BNAME(BAND)
 LCD.PUTSTR(S$)
 IF BAND=0 THEN
  REM -- FM: Put Frequency --
  LCD.PUTSTR(DEC$(PFREQ(PRGSEL)/1000))
  LCD.PUTCHR($2E)
  LCD.PUTSTR(DEC$((PFREQ(PRGSEL)/100)%10))
  LCD.PUTSTR("MHz")

 ELSEIF BAND=1 THEN
  REM -- AM: Put Frequency --
  LCD.PUTSTR(DEC$(PFREQ(PRGSEL)))
  LCD.PUTSTR("KHz ")

 ELSE
  REM -- Others: Put Tune Value --
  LCD.PUTSTR("[")
  IF TUNE<1000 THEN LCD.PUTCHR($20)
  IF TUNE< 100 THEN LCD.PUTCHR($20)
  IF TUNE<  10 THEN LCD.PUTCHR($20)
  LCD.PUTSTR(DEC$(TUNE))
  LCD.PUTSTR("] ")
 ENDIF
 GOSUB DSPVOL
RETURN


REM ---------------------------------
REM         Manual Tuning
REM ---------------------------------

REM Left,Right     Change Frequency
REM Left,Right(1s) Change Freq Fast
REM Up,Down        Change Volume
REM Fire           Change Band (+)
REM Fire (1s)      Set Clock
REM Start          Prgram mode
REM Start(1s)      Search mode

LABEL MNTUNE
 VAR T,B,V
 IF CHGFLG THEN
  CHGFLG=0
  GOSUB DSPTUN
  GOSUB PRADIO
 ENDIF
 GOSUB DSPTIM

 T=TUNE:B=BAND:V=VOL
 IF BT.BLT2 THEN TUNE=TUNE-1
 IF BT.BRT2 THEN TUNE=TUNE+1
 IF BT.BLTCT>=60 THEN TUNE=TUNE-1
 IF BT.BRTCT>=60 THEN TUNE=TUNE+1
 TUNE=(TUNE+2731)%2731
 IF BT.BDN2!=0 AND VOL>0 THEN VOL=VOL-1
 IF BT.BUP2!=0 AND VOL<16 THEN VOL=VOL+1
 IF BT.BFR3 THEN BAND=(BAND+1)%(BNUM)
 IF BT.BST3 THEN MODE=0:LCD.CLR()
 IF BT.BSTCT>=60 THEN GOSUB SEEK
 IF BT.BFRCT>=60 THEN
  LCD.CLR()
  GOSUB SETCLK
  T=-1
 ENDIF
 CHGFLG=(T!=TUNE)+(B!=BAND)+(V!=VOL)+(MODE!=1)
RETURN

REM -- Display Manual Tuning Mode --
LABEL DSPTUN
 LCD.CUR(0,0)
 LCD.PUTSTR("Tune Mode")
 LCD.CUR(0,1)
 S=BNAME(BAND)
 LCD.PUTSTR(S$)
 LCD.PUTSTR("[")
 IF TUNE<1000 THEN LCD.PUTCHR($20)
 IF TUNE< 100 THEN LCD.PUTCHR($20)
 IF TUNE<  10 THEN LCD.PUTCHR($20)
 LCD.PUTSTR(DEC$(TUNE))
 LCD.PUTSTR("]")
 GOSUB DSPVOL
RETURN


REM ---------------------------------
REM      Search Radio Stations
REM ---------------------------------

REM Auto increment frequency
REM Found radio stations, Stop for 2 seconds
REM Up,Down  Change Volume
REM Start    Escape from this mode

LABEL SEEK
 VAR T,V,C,D,E

 C=0:D=0:E=0
 DO
  WAIT 1
  BT.RD()

  IF CHGFLG THEN
   CHGFLG=0
   GOSUB DSPSEK
   GOSUB PRADIO
  ENDIF
  GOSUB DSPTIM

  T=TUNE:V=VOL

  IF C>1 THEN
   C=C-1
  ELSEIF C=1 THEN
   IF PEEK($BF886120) AND $80 THEN
    TUNE=(TUNE+2732)%2731
   ELSE
    D=D+1
    IF D=5 THEN
     D=0
     C=0
     TUNE=(TUNE+2732)%2731
    ENDIF
   ENDIF
  ELSE
   REM Read Tuned Signal
   IF PEEK($BF886120) AND $80 THEN
    D=D+1
    IF D>=5 THEN
     D=0
     E=E+1
     IF E>=3 THEN
      E=0:C=120  :REM Found!
     ELSE
      TUNE=(TUNE+2732)%2731
     ENDIF
    ENDIF
   ELSE
    TUNE=(TUNE+2732)%2731
   ENDIF
  ENDIF

  IF BT.BDN2!=0 AND VOL>0 THEN VOL=VOL-1
  IF BT.BUP2!=0 AND VOL<16 THEN VOL=VOL+1
  IF BT.BST2 THEN BREAK
  CHGFLG=(T!=TUNE)+(V!=VOL)+(MODE!=2)+(C=120)
 LOOP

 REM Wait until Start Button Released
 DO
  WAIT 1
  BT.RD()
 LOOP UNTIL BT.BST3
 LCD.CLR()
RETURN


REM -- Display Search Mode --
LABEL DSPSEK
 LCD.CUR(0,0)
 IF C THEN
  LCD.PUTSTR("Found!   ")
 ELSE
  LCD.PUTSTR("Searching")
 ENDIF
 LCD.CUR(0,1)
 S=BNAME(BAND)
 LCD.PUTSTR(S$)
 LCD.PUTSTR("[")
 IF TUNE<1000 THEN LCD.PUTCHR($20)
 IF TUNE< 100 THEN LCD.PUTCHR($20)
 IF TUNE<  10 THEN LCD.PUTCHR($20)
 LCD.PUTSTR(DEC$(TUNE))
 LCD.PUTSTR("]")
 GOSUB DSPVOL
RETURN


REM ---------------------------------
REM            Set Clock
REM ---------------------------------

LABEL SETCLK

 VAR P,Q,T,Y,M,D,H,N,S
 Y=RT.YEAR:M=RT.MONTH:D=RT.DAY
 H=RT.HOUR:N=RT.MIN:S=RT.SEC
 LCD.CUR(0,0):LCD.PUTSTR(DEC$(2000+Y))
 LCD.PUTSTR("/")
 LCD.PUTCHR($30+M/10):LCD.PUTCHR($30+M%10)
 LCD.PUTSTR("/")
 LCD.PUTCHR($30+D/10):LCD.PUTCHR($30+D%10)
 LCD.PUTSTR("SET=FR")
 LCD.CUR(0,1)
 LCD.PUTCHR($30+H/10):LCD.PUTCHR($30+H%10)
 LCD.PUTSTR(":")
 LCD.PUTCHR($30+N/10):LCD.PUTCHR($30+N%10)
 LCD.PUTSTR(":")
 LCD.PUTCHR($30+S/10):LCD.PUTCHR($30+S%10)
 LCD.PUTSTR("  ESC=ST")

 P=3:Q=H:LCD.CUR(1,1,1)
 DO
  WAIT 1
  BT.RD()

  T=P
  IF BT.BLT2 THEN P=P-1
  IF BT.BRT2 THEN P=P+1
  P=(P+6)%6
  IF P!=T THEN
   IF P=0 THEN
    LCD.CUR(3,0,1):Q=Y
   ELSEIF P=1 THEN
    LCD.CUR(6,0,1):Q=M
   ELSEIF P=2 THEN
    LCD.CUR(9,0,1):Q=D
   ELSEIF P=3 THEN
    LCD.CUR(1,1,1):Q=H
   ELSEIF P=4 THEN
    LCD.CUR(4,1,1):Q=N
   ELSEIF P=5 THEN
    LCD.CUR(7,1,1):Q=S
   ENDIF
  ENDIF
  T=Q
  IF BT.BUP2 + (BT.BUPCT>=60) THEN Q=Q+1
  IF BT.BDN2 + (BT.BDNCT>=60) THEN Q=Q-1

  IF P=0 THEN
   Q=(Q+100)%100
  ELSEIF P=1 THEN
   Q=(Q+11)%12+1
  ELSEIF P=2 THEN
   Q=(Q+30)%31+1
  ELSEIF P=3 THEN
   Q=(Q+24)%24
  ELSE
   Q=(Q+60)%60
  ENDIF

  IF Q!=T THEN
   IF P=0 THEN
    LCD.CUR(0,0):Y=Q
    LCD.PUTSTR(DEC$(2000+Y))
    LCD.CUR(3,0,1)
   ELSEIF P=1 THEN
    LCD.CUR(5,0):M=Q
    LCD.PUTCHR($30+Q/10):LCD.PUTCHR($30+Q%10)
    LCD.CUR(6,0,1)
   ELSEIF P=2 THEN
    LCD.CUR(8,0):D=Q
    LCD.PUTCHR($30+Q/10):LCD.PUTCHR($30+Q%10)
    LCD.CUR(9,0,1)
   ELSEIF P=3 THEN
    LCD.CUR(0,1):H=Q
    LCD.PUTCHR($30+Q/10):LCD.PUTCHR($30+Q%10)
    LCD.CUR(1,1,1)
   ELSEIF P=4 THEN
    LCD.CUR(3,1):N=Q
    LCD.PUTCHR($30+Q/10):LCD.PUTCHR($30+Q%10)
    LCD.CUR(4,1,1)
   ELSEIF P=5 THEN
    LCD.CUR(6,1):S=Q
    LCD.PUTCHR($30+Q/10):LCD.PUTCHR($30+Q%10)
    LCD.CUR(7,1,1)
   ENDIF
  ENDIF

  IF BT.BFR2 THEN
   IF M=2 THEN
    IF D-(Y%4=0)>28 THEN CONTINUE
   ELSEIF ((M+(M<8)) AND 1) THEN
    IF D>30 THEN CONTINUE
   ENDIF
   RT.SETTM(Y,M,D,H,N,S)
   BREAK
  ELSEIF BT.BST3 THEN
   BREAK
  ENDIF
 LOOP

 REM Wait if Fire Button Pressed
 DO
  WAIT 1
  BT.RD()
 LOOP WHILE BT.BFR
 LCD.CLR():LCD.CUR(0,0,0)
RETURN

REM --------------------------------
REM       Display Volume Level
REM --------------------------------
LABEL DSPVOL
 LCD.CUR(15,0)
 IF VOL<9 THEN
  LCD.PUTCHR($20)
 ELSE
  LCD.PUTCHR(VOL-9)
 ENDIF
 LCD.CUR(15,1)
 IF VOL=0 THEN
  LCD.PUTCHR($20)
 ELSEIF VOL<8 THEN
  LCD.PUTCHR(VOL-1)
 ELSE
  LCD.PUTCHR(7)
 ENDIF
RETURN

REM --------------------------------
REM      Display Clock(hh:mm)
REM --------------------------------
LABEL DSPTIM
 RT.RD()
 IF SECOND=RT.SEC THEN RETURN
 SECOND=RT.SEC
 LCD.CUR(10,0)
 LCD.PUTCHR($30+RT.HOUR/10)
 LCD.PUTCHR($30+RT.HOUR%10)
 LCD.PUTCHR($3A)
 LCD.PUTCHR($30+RT.MIN/10)
 LCD.PUTCHR($30+RT.MIN%10)
RETURN


REM --------------------------------
REM Control DSP6959 by DA Converters
REM --------------------------------

LABEL PRADIO
 REM TUNE  0-2730
 REM VOL   0-16
 REM BAND  Band Number

 VAR D

 REM MCP4922 SPI 10MHz/16bit/Mode0/CS:D9pin
 SPI 10000,16,0
 SPIWRITE $B000+TUNE+1365   :REM output ch-B
 SPIWRITE $3000+VOL*170+1365:REM output ch-A

 REM MCP4911 SPI 10MHz/16bit/Mode0/CS:B6pin
 SPI 10000,16,0,$16

 D=BNUMBR(BAND)
 IF D=18 THEN
  D=1023
 ELSEIF D>0 THEN
  D=(D-1)*19375/1000+155
 ELSE
  D=0
 ENDIF
 SPIWRITE $3000+(D<<2)
RETURN

REM --------------------------------
REM    Band Level and Band Name
REM --------------------------------
LABEL BLIST
DATA 17,"FM "
DATA 14,"AM "
DATA 12,"90m"
DATA 11,"60m"
DATA 10,"49m"
DATA  9,"41m"
DATA  8,"31m"
DATA  7,"25m"
DATA  6,"22m"
DATA  5,"19m"
DATA  4,"16m"
DATA  3,"15m"
DATA  2,"13m"
DATA -1

REM ----------------------------------
REM   Programmed Radio Stations List
REM ----------------------------------
REM BandNum,TuneValue,StationName
REM  BandNum 0:FM 1:AM 2-:SW
REM  If BandNum=0 or 1, Frequency[KHz]
REM   instead of TuneValue

LABEL PLIST
DATA 0,78000,"bayfm    "
DATA 0,79500,"Nack5    "
DATA 0,80000,"Tokyo FM "
DATA 0,81300,"J-WAVE   "
DATA 0,82500,"NHK-FM   "
DATA 0,89700,"InterFM  "
DATA 0,90500,"TBS×¼Þµ  "
DATA 0,91600,"ÌÞÝ¶Î³¿³ "
DATA 0,92400,"×¼ÞµÆ¯ÎßÝ"
DATA 0,93000,"Æ¯ÎßÝÎ³¿³"
DATA 1,  594,"NHK×¼Þµ1 "
DATA 1,  693,"NHK×¼Þµ2 "
DATA 1,  810,"AFN Eagle"
DATA 1,  954,"TBS×¼Þµ  "
DATA 1, 1134,"ÌÞÝ¶Î³¿³ "
DATA 1, 1242,"Æ¯ÎßÝÎ³¿³"
DATA 1, 1422,"×¼ÞµÆ¯ÎßÝ"
DATA -1

REM -------------
REM  Volume Font
REM -------------
LABEL FONT
DATA $00000000,$0000001F
DATA $00000000,$00001F1F
DATA $00000000,$001F1F1F
DATA $00000000,$1F1F1F1F
DATA $0000001F,$1F1F1F1F
DATA $00001F1F,$1F1F1F1F
DATA $001F1F1F,$1F1F1F1F
DATA $1F1F1F1F,$1F1F1F1F
