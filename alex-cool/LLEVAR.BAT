@Echo OFF

Rem           ***    Versi¢n 1.79 del LLEVAR,  por Alex Soft   ***

Rem           ***      Compatible con Windows 2000 / ARJ32     ***
Rem           ***    Hasta 30 diskettes / Nueva instalaci¢n    ***


Rem ***  Este BAT fu‚ creado durante el transcurso de un curso de D.O.S,  ***
Rem ***  y con el £nico prop¢sito de explicar la utilizaci¢n de diversos  ***
Rem ***  comandos. Por esa raz¢n fu‚ modificado numerosas veces durante   ***
Rem ***  las clases y en muchas otras ocasiones.                          ***

Rem ***  Esa es la raz¢n o "excusa" para justificar la desprolijidad del  ***
Rem ***  c¢digo  >;-).                                                    ***

Rem ***  No obstante, creo que esta peque¤a utilidad es LO MEJOR para     ***
Rem ***  transportar cosas que ocupar¡an m s de 1 diskette. Eso s¡, tiene ***
Rem ***  un l¡mite de 30 diskettes, pero te avisa ANTES si te pas s.      ***

Rem * Los archivos necesarios son: LLEVAR.BAT, ASK.EXE, ARJ.EXE y ARJ32.EXE *


Cls


rem **********************************
rem CONTROL DE ERRORES
Cls
If not exist %windir%\nul Goto erwin
:volver
If not exist %windir%\ask.exe Goto erask
If not exist %TEMP%\NUL Goto ertemp
:volver2
If not exist %windir%\arj.exe Goto erarj
If not exist %windir%\llevar.bat Goto erpract
If "%1"=="" Goto faltpar
Set #@=12345678
If "%#@%"=="12345678" Goto entornok
Echo No hay suficiente espacio de entorno, imposible continuar.
Echo Prob  agregando esta linea a tu config.sys:  SHELL=C:\COMMAND.COM /E:2048 /P
Echo.
Goto fin

:entornok
Goto arranc
:erwin
If not exist c:\dos\LLEVAR.BAT goto erwin2
If not exist c:\dos\ASK.EXE goto erwin2
If not exist c:\dos\ARJ.EXE goto erwin2
set windir=C:\DOS
If not exist %windir%\LLEVAR.BAT goto erwin2
If not exist %windir%\ASK.EXE goto erwin2
If not exist %windir%\ARJ.EXE goto erwin2
Goto volver
:erwin2
Echo No se encuentra el directorio de WINDOWS, imposible continuar.
Goto fin
:ertemp
MD C:\TEMP
SET TEMP=C:\TEMP
IF NOT EXIST %TEMP%\NUL GOTO ertemp2
Goto volver
:ertemp2
Echo No existe el directorio TEMPORAL, imposible continuar.
Goto fin
:erask
Echo No existe el archivo ask.exe en el directorio de WINDOWS, imposible
Echo continuar.
Goto fin
:erformat
Echo No existe el archivo format.com en el directorio de WINDOWS\COMMAND
Echo imposible continuar.
Goto fin
:erarj
Echo No existe el archivo arj.exe en el directorio de WINDOWS
Echo imposible continuar.
Goto fin
:erpract
Echo No existe el archivo llevar.bat en el directorio de WINDOWS
Echo imposible continuar.
Goto fin
:mnda
Cls
If exist %1\nul goto esundir
IF "%OS%"=="Windows_NT" goto nttest1
goto snttest1
:nttest1
rem *** Aqui comienza una comprobaci¢n que solo se hace en NT ***
If not exist %1 goto snttest1
goto esundir
rem *** Arriba hice el salto pero no es seguro que sea una carpeta
:snttest1
rem *** Termina la comprobaci¢n en NT ***

Echo El nombre que indicaste (%1) no es un nombre de carpeta v lido.
Echo Ten‚s que utilizar el nombre de la carpeta que queres llevarte.
:faltpar
Echo.
Echo.
Echo.
Echo - En Windows, si quieres llevarte una carpeta en diskettes, debes ARRASTRARLA
Echo   sobre este icono, y nada m s !!! As¡ de f cil.
Echo.
Echo.
Echo.
Echo.
Echo - En DOS, en cambio, debes escribir:
Echo.
Echo                   LLEVAR [nombre]
Echo.
Echo Donde [nombre] es justamente el nombre de la carpeta que queres llevarte.
Echo Por ejemplo, si te estas llevando el Pacman, y el mismo se encuentra en la
Echo carpeta C:\PACMAN, entonces deberias IR a esa carpeta, y luego escribir
Echo.
Echo     "LLEVAR PACMAN"
Echo.
Echo (sin las comillas, claro est ).
Goto fin
:olvdir
Cls
Echo ¨Seguro que te metiste en la carpeta de lo que queres llevarte?
Echo De momento te encontras en la siguiente carpeta:
cd
Echo.
Echo And  primero a la carpeta de lo que quer‚s llevarte.
Goto fin
:maxdisc
Cls
Echo Esta utilidad solo puede copiar hasta 30 diskettes y lo que usted est 
Echo comprimiendo ocupa m s.
Echo Use otro programa, o consiga una versi¢n m s mueva de esta utilidad (si
Echo es que la hay).
Goto fin
rem **********************************
:arranc

rem **** Verificar si lo que la persona escribi¢ pudo usarse como nombre ****
md %temp%\%1
If exist %temp%\%1\nul Goto okmd
Goto mnda
:okmd
rd %temp%\%1
Echo Alex >%temp%\%1.tmp
If exist %temp%\%1.tmp Goto okca
Goto mnda
:esundir
CD %1
If exist %temp%\alx_ll_f*.* del %temp%\alx_ll_f*.*
Set #@=__TRAIDO
Goto unicomp

:okca
Del %temp%\%1.tmp
If exist %temp%\alx_ll_f*.* del %temp%\alx_ll_f*.*
If exist command.com Goto olvdir
If exist win.com Goto olvdir
Set #@=%1

rem ************ Fin de verificaci¢n ************


:unicomp
Echo n>%temp%\cletra_n.tmp
If exist %windir%\Escritorio\nul goto compri2
Echo prueba >"%userprofile%\escritorio\alxt-t-dedw2k.alx"
Cls
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO.
ECHO                     Comprimiendo, por favor espere...
ECHO.
If exist "%userprofile%\escritorio\alxt-t-dedw2k.alx" goto compri2
Call arj a %temp%\alx_ll_f -vv1440r240k -jyv -r -a1>NUL
Goto yacompri
:compri2
If exist "%userprofile%\escritorio\alxt-t-dedw2k.alx" Del "%userprofile%\escritorio\alxt-t-dedw2k.alx"
Call arj32 a %temp%\alx_ll_f -vv1440r240k -jyv -r -a1>NUL


:yacompri
If exist %temp%\alx_ll_f.a30 Goto maxdisc
Cls
Echo.
If exist %temp%\alx_ll_f.a29 Echo                            Necesitar  30 diskettes
If exist %temp%\alx_ll_f.a29 Goto nmm
If exist %temp%\alx_ll_f.a28 Echo                            Necesitar  29 diskettes
If exist %temp%\alx_ll_f.a28 Goto nmm
If exist %temp%\alx_ll_f.a27 Echo                            Necesitar  28 diskettes
If exist %temp%\alx_ll_f.a27 Goto nmm
If exist %temp%\alx_ll_f.a26 Echo                            Necesitar  27 diskettes
If exist %temp%\alx_ll_f.a26 Goto nmm
If exist %temp%\alx_ll_f.a25 Echo                            Necesitar  26 diskettes
If exist %temp%\alx_ll_f.a25 Goto nmm
If exist %temp%\alx_ll_f.a24 Echo                            Necesitar  25 diskettes
If exist %temp%\alx_ll_f.a24 Goto nmm
If exist %temp%\alx_ll_f.a23 Echo                            Necesitar  24 diskettes
If exist %temp%\alx_ll_f.a23 Goto nmm
If exist %temp%\alx_ll_f.a22 Echo                            Necesitar  23 diskettes
If exist %temp%\alx_ll_f.a22 Goto nmm
If exist %temp%\alx_ll_f.a21 Echo                            Necesitar  22 diskettes
If exist %temp%\alx_ll_f.a21 Goto nmm
If exist %temp%\alx_ll_f.a20 Echo                            Necesitar  21 diskettes
If exist %temp%\alx_ll_f.a20 Goto nmm
If exist %temp%\alx_ll_f.a19 Echo                            Necesitar  20 diskettes
If exist %temp%\alx_ll_f.a19 Goto nmm
If exist %temp%\alx_ll_f.a18 Echo                            Necesitar  19 diskettes
If exist %temp%\alx_ll_f.a18 Goto nmm
If exist %temp%\alx_ll_f.a17 Echo                            Necesitar  18 diskettes
If exist %temp%\alx_ll_f.a17 Goto nmm
If exist %temp%\alx_ll_f.a16 Echo                            Necesitar  17 diskettes
If exist %temp%\alx_ll_f.a16 Goto nmm
If exist %temp%\alx_ll_f.a15 Echo                            Necesitar  16 diskettes
If exist %temp%\alx_ll_f.a15 Goto nmm
If exist %temp%\alx_ll_f.a14 Echo                            Necesitar  15 diskettes
If exist %temp%\alx_ll_f.a14 Goto nmm
If exist %temp%\alx_ll_f.a13 Echo                            Necesitar  14 diskettes
If exist %temp%\alx_ll_f.a13 Goto nmm
If exist %temp%\alx_ll_f.a12 Echo                            Necesitar  13 diskettes
If exist %temp%\alx_ll_f.a12 Goto nmm
If exist %temp%\alx_ll_f.a11 Echo                            Necesitar  12 diskettes
If exist %temp%\alx_ll_f.a11 Goto nmm
If exist %temp%\alx_ll_f.a10 Echo                            Necesitar  11 diskettes
If exist %temp%\alx_ll_f.a10 Goto nmm
If exist %temp%\alx_ll_f.a09 Echo                            Necesitar  10 diskettes
If exist %temp%\alx_ll_f.a09 Goto nmm
If exist %temp%\alx_ll_f.a08 Echo                            Necesitar  9 diskettes
If exist %temp%\alx_ll_f.a08 Goto nmm
If exist %temp%\alx_ll_f.a07 Echo                            Necesitar  8 diskettes
If exist %temp%\alx_ll_f.a07 Goto nmm
If exist %temp%\alx_ll_f.a06 Echo                            Necesitar  7 diskettes
If exist %temp%\alx_ll_f.a06 Goto nmm
If exist %temp%\alx_ll_f.a05 Echo                            Necesitar  6 diskettes
If exist %temp%\alx_ll_f.a05 Goto nmm
If exist %temp%\alx_ll_f.a04 Echo                            Necesitar  5 diskettes
If exist %temp%\alx_ll_f.a04 Goto nmm
If exist %temp%\alx_ll_f.a03 Echo                            Necesitar  4 diskettes
If exist %temp%\alx_ll_f.a03 Goto nmm
If exist %temp%\alx_ll_f.a02 Echo                            Necesitar  3 diskettes
If exist %temp%\alx_ll_f.a02 Goto nmm
If exist %temp%\alx_ll_f.a01 Echo                            Necesitar  2 diskettes
If not exist %temp%\alx_ll_f.a01 Echo                            Necesitar  solo 1 diskette.
If not exist %temp%\alx_ll_f.a01 Goto solo1dis

:nmm
Echo.
Echo Inserte el primer diskette vac¡o
:solo1dis
Echo (Se proceder  a copiarlo)
Call ask "Desea continuar con la copia? (S/N) ", SN
If errorlevel 2 Goto final
If errorlevel 1 Goto copia



:copia
rem ******************************* Inicio creacion bat instalacion
ECHO @ECHO OFF>%temp%\tmpipca2.bat
ECHO DEL C:\tmp_x_ll.tmp\*.EXE>>%temp%\tmpipca2.bat
ECHO DEL C:\tmp_x_ll.tmp\*.BAT>>%temp%\tmpipca2.bat
ECHO DEL C:\tmp_x_ll.tmp\*.A*>>%temp%\tmpipca2.bat
ECHO RD C:\tmp_x_ll.tmp>>%temp%\tmpipca2.bat
ECHO CLS>>%temp%\tmpipca2.bat
ECHO IF EXIST C:\tmp_x_ll.tmp\NUL CALL DELTREE /Y C:\tmp_x_ll.tmp>>%temp%\tmpipca2.bat
ECHO EXIT>>%temp%\tmpipca2.bat
ECHO @ECHO OFF>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando disco 1, por favor espere...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO C:>>%temp%\tmpipcad.bat
ECHO CD C:\tmp_x_ll.tmp\>>%temp%\tmpipcad.bat
ECHO COPY A:*.ARJ>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Por favor espere...>>%temp%\tmpipcad.bat
ECHO COPY A:ARJ.EXE>>%temp%\tmpipcad.bat
ECHO IF EXIST *.ARJ GOTO COPYIDN2>>%temp%\tmpipcad.bat
ECHO :ERROR>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Hubo un error copiando este disco. No tiene sentido proseguir, deber >>%temp%\tmpipcad.bat
ECHO ECHO volver a copiar todo el set nuevamente. Para que esto no ocurra de nuevo,>>%temp%\tmpipcad.bat
ECHO ECHO por favor asegurese de VERIFICAR los diskettes cuando termina de copiarlos>>%temp%\tmpipcad.bat
ECHO ECHO con el llevar. A£n asi, es normal que los mismos se da¤en a menudo.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO PAUSE>>%temp%\tmpipcad.bat
ECHO GOTO FINAL>>%temp%\tmpipcad.bat
ECHO :COPYIDN2>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST ARJ.EXE GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:ONLY.ALX GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 2  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A01>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A01 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 3  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A02>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A02 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 4  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A03>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A03 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 5  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A04>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A04 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 6  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A05>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A05 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 7  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A06>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A06 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 8  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A07>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A07 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 9  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A08>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A08 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 10 y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A09>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A09 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 11  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A10>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A10 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 12  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A11>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A11 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 13  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A12>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A12 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 14  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A13>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A13 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 15  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A14>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A14 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 16  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A15>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A15 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 17  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A16>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A16 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 18  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A17>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A17 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 19  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A18>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A18 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 20 y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A19>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A19 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 21  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A20>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A20 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 22  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A21>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A21 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 23  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A22>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A22 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 24  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A23>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A23 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 25  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A24>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A24 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 26  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A25>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A25 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 27  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A26>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A26 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 28  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A27>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A27 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 29  y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A28>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A28 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO Inserte el disco 30 y presione cualquier tecla para continuar...>>%temp%\tmpipcad.bat
ECHO PAUSE>NUL>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Copiando...>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO COPY A:*.A29>>%temp%\tmpipcad.bat
ECHO IF NOT EXIST *.A29 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO IF EXIST A:INSTALAR.BAT GOTO FINCOPY>>%temp%\tmpipcad.bat
ECHO :FINCOPY>>%temp%\tmpipcad.bat
ECHO Arj x *.arj c:\%#@%\ -jycov -vv -hf3>>%temp%\tmpipcad.bat
ECHO IF ERRORLEVEL 1 GOTO ERROR>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Proceso conclu¡do. A continuaci¢n, se abrir  una ventana conteniendo los>>%temp%\tmpipcad.bat
ECHO ECHO archivos extra¡dos de los diskettes. Si no te encuentras en Windows, puede>>%temp%\tmpipcad.bat
ECHO ECHO que aparezca un mensaje de error>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO Solo en caso de que quieras saberlo, la carpeta donde se copi¢ lo que>>%temp%\tmpipcad.bat
ECHO ECHO acab s de instalar es "C:\%#@%".>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO ECHO.>>%temp%\tmpipcad.bat
ECHO PAUSE>>%temp%\tmpipcad.bat
ECHO CLS>>%temp%\tmpipcad.bat
ECHO DEL *.A*>>%temp%\tmpipcad.bat
ECHO DEL ARJ.EXE>>%temp%\tmpipcad.bat
ECHO CD c:\%#@%>>%temp%\tmpipcad.bat
ECHO START .>>%temp%\tmpipcad.bat
ECHO If exist c:\windows\win.com c:\windows\tmpipca2.bat>>%temp%\tmpipcad.bat
ECHO EXIT>>%temp%\tmpipcad.bat
ECHO :FINAL>>%temp%\tmpipcad.bat
ECHO DEL *.A*>>%temp%\tmpipcad.bat
ECHO DEL ARJ.EXE>>%temp%\tmpipcad.bat
ECHO If exist c:\windows\win.com c:\windows\tmpipca2.bat>>%temp%\tmpipcad.bat

rem ******************************* Fin creacion bat instalaci¢n
rem ************ Inicio creacion segundo bat instalaci¢n
Echo @Echo off>%temp%\instalar.bat
Echo Cls>>%temp%\instalar.bat
Echo Echo Este proceso instalar  el contenido de este set de diskettes en la carpeta>>%temp%\instalar.bat
Echo Echo %#@% de la unidad C:.>>%temp%\instalar.bat
Echo Echo.>>%temp%\instalar.bat
Echo Echo Presione CTRL + C si desea cancelar la instalaci¢n en este momento, o bien>>%temp%\instalar.bat
Echo Pause>>%temp%\instalar.bat
Echo Cls>>%temp%\instalar.bat
Echo IF EXIST C:\tmp_x_ll.tmp\tmpipcad.bat GOTO NOCREAR>>%temp%\instalar.bat
Echo MD C:\tmp_x_ll.tmp>>%temp%\instalar.bat
Echo :nocrear>>%temp%\instalar.bat
Echo COPY tmpipcad.bat C:\tmp_x_ll.tmp>>%temp%\instalar.bat
Echo If exist c:\windows\win.com COPY tmpipca2.bat c:\windows>>%temp%\instalar.bat
Echo C:>>%temp%\instalar.bat
Echo CD C:\tmp_x_ll.tmp>>%temp%\instalar.bat
Echo tmpipcad.bat>>%temp%\instalar.bat
REM ********* Fin creacion segundo bat instalacion

Cls
Echo COPIANDO...........
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
rem ***************
Copy %temp%\instalar.bat a:>nul
Copy %temp%\tmpipca2.bat a:>nul
Copy %temp%\tmpipcad.bat a:>nul
Copy %windir%\arj.exe a:\ >nul
rem ***************
Copy %temp%\alx_ll_f.arj a:\%#@%.arj
If exist a:\%#@%.arj Goto nocope1
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia
:nocope1
If not exist %temp%\alx_ll_f.a01 echo Unico>a:only.alx
If not exist %temp%\alx_ll_f.a01 Goto testeo

:copia2
Cls
Echo Inserte el segundo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a01 a:\%#@%.a01
If exist a:\%#@%.a01 Goto nocope2
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia2
:nocope2
If not exist  %temp%\alx_ll_f.a02 Goto testeo
Echo.

:copia3
Cls
Echo Inserte el tercer diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a02 a:\%#@%.a02
If exist a:\%#@%.a02 Goto nocope3
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia3
:nocope3
If not exist  %temp%\alx_ll_f.a03 Goto testeo
Echo.

:copia4
Cls
Echo Inserte el cuarto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a03 a:\%#@%.a03
If exist a:\%#@%.a03 Goto nocope4
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia4
:nocope4
If not exist  %temp%\alx_ll_f.a04 Goto testeo
Echo.

:copia5
Cls
Echo Inserte el quinto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a04 a:\%#@%.a04
If exist a:\%#@%.a04 Goto nocope5
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia5
:nocope5
If not exist  %temp%\alx_ll_f.a05 Goto testeo
Echo.

:copia6
Cls
Echo Inserte el sexto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a05 a:\%#@%.a05
If exist a:\%#@%.a05 Goto nocope6
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia6
:nocope6
If not exist  %temp%\alx_ll_f.a06 Goto testeo
Echo.

:copia7
Cls
Echo Inserte el septimo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a06 a:\%#@%.a06
If exist a:\%#@%.a06 Goto nocope7
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia7
:nocope7
If not exist  %temp%\alx_ll_f.a07 Goto testeo
Echo.

:copia8
Cls
Echo Inserte el octavo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a07 a:\%#@%.a07
If exist a:\%#@%.a07 Goto nocope8
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia8
:nocope8
If not exist  %temp%\alx_ll_f.a08 Goto testeo
Echo.

:copia9
Cls
Echo Inserte el noveno diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a08 a:\%#@%.a08
If exist a:\%#@%.a08 Goto nocope9
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia9
:nocope9
If not exist  %temp%\alx_ll_f.a09 Goto testeo
Echo.

:copia10
Cls
Echo Inserte el d‚cimo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a09 a:\%#@%.a09
If exist a:\%#@%.a09 Goto nocope10
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia10
:nocope10
If not exist  %temp%\alx_ll_f.a10 Goto testeo
Echo.

rem **** A partir de aca  viene el disco 11
***********
:copia11
Cls
Echo Inserte el d‚cimo primer diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a10 a:\%#@%.a10
If exist a:\%#@%.a10 Goto nocope11
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia11
:nocope11
If not exist  %temp%\alx_ll_f.a11 Goto testeo
Echo.

:copia12
Cls
Echo Inserte el d‚cimo segundo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a11 a:\%#@%.a11
If exist a:\%#@%.a11 Goto nocope12
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia12
:nocope12
If not exist  %temp%\alx_ll_f.a12 Goto testeo
Echo.

:copia13
Cls
Echo Inserte el d‚cimo tercer diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a12 a:\%#@%.a12
If exist a:\%#@%.a12 Goto nocope13
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia13
:nocope13
If not exist  %temp%\alx_ll_f.a13 Goto testeo
Echo.

:copia14
Cls
Echo Inserte el d‚cimo cuarto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a13 a:\%#@%.a13
If exist a:\%#@%.a13 Goto nocope14
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia14
:nocope14
If not exist  %temp%\alx_ll_f.a14 Goto testeo
Echo.

:copia15
Cls
Echo Inserte el d‚cimo quinto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a14 a:\%#@%.a14
If exist a:\%#@%.a14 Goto nocope15
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia15
:nocope15
If not exist  %temp%\alx_ll_f.a15 Goto testeo
Echo.

:copia16
Cls
Echo Inserte el d‚cimo sexto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a15 a:\%#@%.a15
If exist a:\%#@%.a15 Goto nocope16
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia16
:nocope16
If not exist  %temp%\alx_ll_f.a16 Goto testeo
Echo.

:copia17
Cls
Echo Inserte el d‚cimo s‚ptimo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a16 a:\%#@%.a16
If exist a:\%#@%.a16 Goto nocope17
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia17
:nocope17
If not exist  %temp%\alx_ll_f.a17 Goto testeo
Echo.

:copia18
Cls
Echo Inserte el d‚cimo octavo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a17 a:\%#@%.a17
If exist a:\%#@%.a17 Goto nocope18
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia18
:nocope18
If not exist  %temp%\alx_ll_f.a18 Goto testeo
Echo.

:copia19
Cls
Echo Inserte el d‚cimo noveno diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a18 a:\%#@%.a18
If exist a:\%#@%.a18 Goto nocope19
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia19
:nocope19
If not exist  %temp%\alx_ll_f.a19 Goto testeo
Echo.

:copia20
Cls
Echo Inserte el vig‚simo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a19 a:\%#@%.a19
If exist a:\%#@%.a19 Goto nocope20
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia20
:nocope20
If not exist  %temp%\alx_ll_f.a20 Goto testeo
Echo.

:copia21
Cls
Echo Inserte el vig‚simo primer diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a20 a:\%#@%.a20
If exist a:\%#@%.a20 Goto nocope21
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia21
:nocope21
If not exist  %temp%\alx_ll_f.a21 Goto testeo
Echo.

:copia22
Cls
Echo Inserte el vig‚simo segundo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a21 a:\%#@%.a21
If exist a:\%#@%.a21 Goto nocope22
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia22
:nocope22
If not exist  %temp%\alx_ll_f.a22 Goto testeo
Echo.

:copia23
Cls
Echo Inserte el vig‚simo tercer diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a22 a:\%#@%.a22
If exist a:\%#@%.a22 Goto nocope23
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia23
:nocope23
If not exist  %temp%\alx_ll_f.a23 Goto testeo
Echo.

:copia24
Cls
Echo Inserte el vig‚simo cuarto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a23 a:\%#@%.a23
If exist a:\%#@%.a23 Goto nocope24
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia24
:nocope24
If not exist  %temp%\alx_ll_f.a24 Goto testeo
Echo.

:copia25
Cls
Echo Inserte el vig‚simo quinto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a24 a:\%#@%.a24
If exist a:\%#@%.a24 Goto nocope25
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia25
:nocope25
If not exist  %temp%\alx_ll_f.a25 Goto testeo
Echo.

:copia26
Cls
Echo Inserte el vig‚simo sexto diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a25 a:\%#@%.a25
If exist a:\%#@%.a25 Goto nocope26
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia26
:nocope26
If not exist  %temp%\alx_ll_f.a26 Goto testeo
Echo.

:copia27
Cls
Echo Inserte el vig‚simo septimo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a26 a:\%#@%.a26
If exist a:\%#@%.a26 Goto nocope27
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia27
:nocope27
If not exist  %temp%\alx_ll_f.a27 Goto testeo
Echo.

:copia28
Cls
Echo Inserte el vig‚simo octavo diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a27 a:\%#@%.a27
If exist a:\%#@%.a27 Goto nocope28
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia28
:nocope28
If not exist  %temp%\alx_ll_f.a28 Goto testeo
Echo.

:copia29
Cls
Echo Inserte el vig‚simo noveno diskette vac¡o
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a28 a:\%#@%.a28
If exist a:\%#@%.a28 Goto nocope29
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia29
:nocope29
If not exist  %temp%\alx_ll_f.a29 Goto testeo
Echo.

:copia29
Cls
Echo Inserte el  diskette vac¡o Nø 30
Pause
Cls
Echo COPIANDO.............
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a29 a:\%#@%.a29
If exist a:\%#@%.a29 Goto nocope30
Cls
Echo ERROR ! DISCO DA¥ADO, REEMPLAZELO POR OTRO.
Pause
Goto copia30
:nocope30
If not exist  %temp%\alx_ll_f.a30 Goto testeo
Echo.



****************************************************************************


:testeo
rem ***************
Echo @Echo off >a:\instalar.bat
Echo Cls>>a:\instalar.bat
Echo Echo Este proceso instalar  el contenido de este set de diskettes en la carpeta>>a:\instalar.bat
Echo Echo %#@% de la unidad C:.>>a:\instalar.bat
Echo Echo.>>a:\instalar.bat
Echo Echo Presione CTRL + C si desea cancelar la instalaci¢n en este momento, o bien>>a:\instalar.bat
Echo Pause>>a:\instalar.bat
Echo Cls>>a:\instalar.bat
Echo IF EXIST C:\tmp_x_ll.tmp\tmpipcad.bat GOTO NOCREAR>>a:\instalar.bat
Echo MD C:\tmp_x_ll.tmp>>a:\instalar.bat
Echo :nocrear>>a:\instalar.bat
Echo COPY tmpipcad.bat C:\tmp_x_ll.tmp>>a:\instalar.bat
Echo C:>>a:\instalar.bat
Echo CD C:\tmp_x_ll.tmp>>a:\instalar.bat
Echo tmpipcad.bat>>a:\instalar.bat
Copy %temp%\tmpipcad.bat a:>nul
rem ***************
If not exist %temp%\alx_ll_f.a01 Goto skiphide
Call Attrib +h a:\instalar.bat
:skiphide
Cls
Echo Se proceder  a verificar los diskettes.
Echo.
Echo -Si desea continuar, INSERTE EL DISCO 1 y presione la S
Echo -Si desea terminar sin revisarlos presione la N
Call ask "Haga su seleccion ", SN
Cls
If errorlevel 2 Goto final
If errorlevel 1 Goto testya

:test
If not exist %temp%\alx_ll_f.a01 Goto solot1d
Goto contest1
:solot1d
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Cls
Goto testya
:contest1
Cls
Echo Inserte el disco 1 
Pause
:testya
If exist a:\%#@%.arj Goto d1ok
Goto TEST
:d1ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.ARJ <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd1
Goto test2
:erd1
Cls
Echo Hubo un error con el disco 1, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format1
If errorlevel 1 Goto reCopy1
:format1
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd1
:reCopy1
Cls
Echo Volviendo a copiar disco 1.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
rem ***************
Copy %temp%\instalar.bat a:>nul
Copy %temp%\tmpipca2.bat a:>nul
Copy %temp%\tmpipcad.bat a:>nul
Copy %windir%\arj.exe a:\ >nul
rem ***************
Copy %temp%\alx_ll_f.arj a:\%#@%.arj
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d1ok

:test2
If not exist %temp%\alx_ll_f.a01 Goto todojoya
Cls
Echo Proceda a insertar disco 2 para que sea verificado.
Pause
If exist a:\%#@%.a01 Goto d2ok
Goto TEST2
:d2ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a01 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd2
Goto test3
:erd2
Cls
Echo Hubo un error con el disco 2, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format2
If errorlevel 1 Goto reCopy2
:format2
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd2
:reCopy2
Cls
Echo Volviendo a copiar disco 2.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a01 a:\%#@%.a01
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d2ok

:test3
If not exist %temp%\alx_ll_f.a02 Goto todojoya
Cls
Echo Proceda a insertar disco 3 para que sea verificado. 
Pause
If exist a:\%#@%.a02 Goto d3ok
Goto TEST3
:d3ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a02 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd3
Goto test4
:erd3
Cls
Echo Hubo un error con el disco 3, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format3
If errorlevel 1 Goto reCopy3
:format3
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd3
:reCopy3
Cls
Echo Volviendo a copiar disco 3.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a02 a:\%#@%.a02
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d3ok

:test4
If not exist %temp%\alx_ll_f.a03 Goto todojoya
Cls
Echo Proceda a insertar disco 4 para que sea verificado.
Pause
If exist a:\%#@%.a03 Goto d4ok
Goto TEST4
:d4ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a03 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd4
Goto test5
:erd4
Cls
Echo Hubo un error con el disco 4, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format4
If errorlevel 1 Goto reCopy4
:format4
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd4
:reCopy4
Cls
Echo Volviendo a copiar disco 4.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a03 a:\%#@%.a03
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d4ok

:test5
If not exist %temp%\alx_ll_f.a04 Goto todojoya
Cls
Echo Proceda a insertar disco 5 para que sea verificado.
Pause
If exist a:\%#@%.a04 Goto d5ok
Goto TEST5
:d5ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a04 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd5
Goto test6
:erd5
Cls
Echo Hubo un error con el disco 5, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format5
If errorlevel 1 Goto reCopy5
:format5
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd5
:reCopy5
Cls
Echo Volviendo a copiar disco 5.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a04 a:\%#@%.a04
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d5ok

:test6
If not exist %temp%\alx_ll_f.a05 Goto todojoya
Cls
Echo Proceda a insertar disco 6 para que sea verificado.
Pause
If exist a:\%#@%.a05 Goto d6ok
Goto TEST6
:d6ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a05 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd6
Goto test7
:erd6
Cls
Echo Hubo un error con el disco 6, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format6
If errorlevel 1 Goto reCopy6
:format6
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd6
:reCopy6
Cls
Echo Volviendo a copiar disco 6.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a05 a:\%#@%.a05
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d6ok

:test7
If not exist %temp%\alx_ll_f.a06 Goto todojoya
Cls
Echo Proceda a insertar disco 7 para que sea verificado.
Pause
If exist a:\%#@%.a06 Goto d7ok
Goto TEST7
:d7ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a06 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd7
Goto test8
:erd7
Cls
Echo Hubo un error con el disco 7, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format7
If errorlevel 1 Goto reCopy7
:format7
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd7
:reCopy7
Cls
Echo Volviendo a copiar disco 7.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a06 a:\%#@%.a06
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d7ok

:test8
If not exist %temp%\alx_ll_f.a07 Goto todojoya
Cls
Echo Proceda a insertar disco 8 para que sea verificado.
Pause
If exist a:\%#@%.a07 Goto d8ok
Goto TEST8
:d8ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a07 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd8
Goto test9
:erd8
Cls
Echo Hubo un error con el disco 8, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format8
If errorlevel 1 Goto reCopy8
:format8
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd8
:reCopy8
Cls
Echo Volviendo a copiar disco 8.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a07 a:\%#@%.a07
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d8ok

:test9
If not exist %temp%\alx_ll_f.a08 Goto todojoya
Cls
Echo Proceda a insertar disco 9 para que sea verificado.
Pause
If exist a:\%#@%.a08 Goto d9ok
Goto TEST9
:d9ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a08 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd9
Goto test10
:erd9
Cls
Echo Hubo un error con el disco 9, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format9
If errorlevel 1 Goto reCopy9
:format9
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd9
:reCopy9
Cls
Echo Volviendo a copiar disco 9.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a08 a:\%#@%.a08
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d9ok

:test10
If not exist %temp%\alx_ll_f.a09 Goto todojoya
Cls
Echo Proceda a insertar disco 10 para que sea verificado.
Pause
If exist a:\%#@%.a09 Goto d10ok
Goto TEST10
:d10ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a09 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd10
Goto test11
:erd10
Cls
Echo Hubo un error con el disco 10, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format10
If errorlevel 1 Goto reCopy10
:format10
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd10
:reCopy10
Cls
Echo Volviendo a copiar disco 10.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a09 a:\%#@%.a09
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d10ok

:test11
If not exist %temp%\alx_ll_f.a10 Goto todojoya
Cls
Echo Proceda a insertar disco 11 para que sea verificado.
Pause
If exist a:\%#@%.a10 Goto d11ok
Goto TEST11
:d11ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a10 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd11
Goto test12
:erd11
Cls
Echo Hubo un error con el disco 11, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format11
If errorlevel 1 Goto reCopy11
:format11
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd11
:reCopy11
Cls
Echo Volviendo a copiar disco 11.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a10 a:\%#@%.a10
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d11ok

:test12
If not exist %temp%\alx_ll_f.a11 Goto todojoya
Cls
Echo Proceda a insertar disco 12 para que sea verificado.
Pause
If exist a:\%#@%.a11 Goto d12ok
Goto TEST12
:d12ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a11 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd12
Goto test13
:erd12
Cls
Echo Hubo un error con el disco 12, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format12
If errorlevel 1 Goto reCopy12
:format12
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd12
:reCopy12
Cls
Echo Volviendo a copiar disco 12.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a11 a:\%#@%.a11
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d12ok

:test13
If not exist %temp%\alx_ll_f.a12 Goto todojoya
Cls
Echo Proceda a insertar disco 13 para que sea verificado.
Pause
If exist a:\%#@%.a12 Goto d13ok
Goto TEST13
:d13ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a12 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd13
Goto test14
:erd13
Cls
Echo Hubo un error con el disco 13, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format13
If errorlevel 1 Goto reCopy13
:format13
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd13
:reCopy13
Cls
Echo Volviendo a copiar disco 13.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a12 a:\%#@%.a12
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d13ok

:test14
If not exist %temp%\alx_ll_f.a13 Goto todojoya
Cls
Echo Proceda a insertar disco 14 para que sea verificado.
Pause
If exist a:\%#@%.a13 Goto d14ok
Goto TEST14
:d14ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a13 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd14
Goto test15
:erd14
Cls
Echo Hubo un error con el disco 14, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format14
If errorlevel 1 Goto reCopy14
:format14
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd14
:reCopy14
Cls
Echo Volviendo a copiar disco 14.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a13 a:\%#@%.a13
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d14ok

:test15
If not exist %temp%\alx_ll_f.a14 Goto todojoya
Cls
Echo Proceda a insertar disco 15 para que sea verificado.
Pause
If exist a:\%#@%.a14 Goto d15ok
Goto TEST15
:d15ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a14 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd15
Goto test16
:erd15
Cls
Echo Hubo un error con el disco 15, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format15
If errorlevel 1 Goto reCopy15
:format15
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd15
:reCopy15
Cls
Echo Volviendo a copiar disco 15.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a14 a:\%#@%.a14
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d15ok

:test16
If not exist %temp%\alx_ll_f.a15 Goto todojoya
Cls
Echo Proceda a insertar disco 16 para que sea verificado.
Pause
If exist a:\%#@%.a15 Goto d16ok
Goto TEST16
:d16ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a15 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd16
Goto test17
:erd16
Cls
Echo Hubo un error con el disco 16, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format16
If errorlevel 1 Goto reCopy16
:format16
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd16
:reCopy16
Cls
Echo Volviendo a copiar disco 16.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a15 a:\%#@%.a15
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d16ok

:test17
If not exist %temp%\alx_ll_f.a16 Goto todojoya
Cls
Echo Proceda a insertar disco 17 para que sea verificado.
Pause
If exist a:\%#@%.a16 Goto d17ok
Goto TEST17
:d17ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a16 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd17
Goto test18
:erd17
Cls
Echo Hubo un error con el disco 17, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format17
If errorlevel 1 Goto reCopy17
:format17
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd17
:reCopy17
Cls
Echo Volviendo a copiar disco 17.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a16 a:\%#@%.a16
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d17ok

:test18
If not exist %temp%\alx_ll_f.a17 Goto todojoya
Cls
Echo Proceda a insertar disco 18 para que sea verificado.
Pause
If exist a:\%#@%.a17 Goto d18ok
Goto TEST18
:d18ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a17 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd18
Goto test19
:erd18
Cls
Echo Hubo un error con el disco 18, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format18
If errorlevel 1 Goto reCopy18
:format18
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd18
:reCopy18
Cls
Echo Volviendo a copiar disco 18.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a17 a:\%#@%.a17
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d18ok

:test19
If not exist %temp%\alx_ll_f.a18 Goto todojoya
Cls
Echo Proceda a insertar disco 19 para que sea verificado.
Pause
If exist a:\%#@%.a18 Goto d19ok
Goto TEST19
:d19ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a18 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd19
Goto test20
:erd19
Cls
Echo Hubo un error con el disco 19, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format19
If errorlevel 1 Goto reCopy19
:format19
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd19
:reCopy19
Cls
Echo Volviendo a copiar disco 19.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a18 a:\%#@%.a18
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d19ok

:test20
If not exist %temp%\alx_ll_f.a19 Goto todojoya
Cls
Echo Proceda a insertar disco 20 para que sea verificado.
Pause
If exist a:\%#@%.a19 Goto d20ok
Goto TEST20
:d20ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a19 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd20
Goto test21
:erd20
Cls
Echo Hubo un error con el disco 20, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format20
If errorlevel 1 Goto reCopy20
:format20
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd20
:reCopy20
Cls
Echo Volviendo a copiar disco 20.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a19 a:\%#@%.a19
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d20ok

:test21
If not exist %temp%\alx_ll_f.a20 Goto todojoya
Cls
Echo Proceda a insertar disco 21 para que sea verificado.
Pause
If exist a:\%#@%.a20 Goto d21ok
Goto TEST21
:d21ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a20 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd21
Goto test22
:erd21
Cls
Echo Hubo un error con el disco 21, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format21
If errorlevel 1 Goto reCopy21
:format21
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd21
:reCopy21
Cls
Echo Volviendo a copiar disco 21.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a20 a:\%#@%.a20
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d21ok

:test22
If not exist %temp%\alx_ll_f.a21 Goto todojoya
Cls
Echo Proceda a insertar disco 22 para que sea verificado.
Pause
If exist a:\%#@%.a21 Goto d22ok
Goto TEST22
:d22ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a21 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd22
Goto test23
:erd22
Cls
Echo Hubo un error con el disco 22, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format22
If errorlevel 1 Goto reCopy22
:format22
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd22
:reCopy22
Cls
Echo Volviendo a copiar disco 22.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a21 a:\%#@%.a21
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d22ok

:test23
If not exist %temp%\alx_ll_f.a22 Goto todojoya
Cls
Echo Proceda a insertar disco 23 para que sea verificado.
Pause
If exist a:\%#@%.a22 Goto d23ok
Goto TEST23
:d23ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a22 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd23
Goto test24
:erd23
Cls
Echo Hubo un error con el disco 23, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format23
If errorlevel 1 Goto reCopy23
:format23
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd23
:reCopy23
Cls
Echo Volviendo a copiar disco 23.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a22 a:\%#@%.a22
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d23ok

:test24
If not exist %temp%\alx_ll_f.a23 Goto todojoya
Cls
Echo Proceda a insertar disco 24 para que sea verificado.
Pause
If exist a:\%#@%.a23 Goto d24ok
Goto TEST24
:d24ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a23 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd24
Goto test25
:erd24
Cls
Echo Hubo un error con el disco 24, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format24
If errorlevel 1 Goto reCopy24
:format24
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd24
:reCopy24
Cls
Echo Volviendo a copiar disco 24.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a23 a:\%#@%.a23
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d24ok

:test25
If not exist %temp%\alx_ll_f.a24 Goto todojoya
Cls
Echo Proceda a insertar disco 25 para que sea verificado.
Pause
If exist a:\%#@%.a24 Goto d25ok
Goto TEST25
:d25ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a24 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd25
Goto test26
:erd25
Cls
Echo Hubo un error con el disco 25, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format25
If errorlevel 1 Goto reCopy25
:format25
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd25
:reCopy25
Cls
Echo Volviendo a copiar disco 25.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a24 a:\%#@%.a24
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d25ok

:test26
If not exist %temp%\alx_ll_f.a25 Goto todojoya
Cls
Echo Proceda a insertar disco 26 para que sea verificado.
Pause
If exist a:\%#@%.a25 Goto d26ok
Goto TEST26
:d26ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a25 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd26
Goto test27
:erd26
Cls
Echo Hubo un error con el disco 26, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format26
If errorlevel 1 Goto reCopy26
:format26
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd26
:reCopy26
Cls
Echo Volviendo a copiar disco 26.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a25 a:\%#@%.a25
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d26ok

:test27
If not exist %temp%\alx_ll_f.a26 Goto todojoya
Cls
Echo Proceda a insertar disco 27 para que sea verificado.
Pause
If exist a:\%#@%.a26 Goto d27ok
Goto TEST27
:d27ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a26 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd27
Goto test28
:erd27
Cls
Echo Hubo un error con el disco 27, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format27
If errorlevel 1 Goto reCopy27
:format27
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd27
:reCopy27
Cls
Echo Volviendo a copiar disco 27.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a26 a:\%#@%.a26
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d27ok

:test28
If not exist %temp%\alx_ll_f.a27 Goto todojoya
Cls
Echo Proceda a insertar disco 28 para que sea verificado.
Pause
If exist a:\%#@%.a27 Goto d28ok
Goto TEST28
:d28ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a27 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd28
Goto test29
:erd28
Cls
Echo Hubo un error con el disco 28, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format28
If errorlevel 1 Goto reCopy28
:format28
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd28
:reCopy28
Cls
Echo Volviendo a copiar disco 28.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a27 a:\%#@%.a27
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d28ok

:test29
If not exist %temp%\alx_ll_f.a28 Goto todojoya
Cls
Echo Proceda a insertar disco 29 para que sea verificado.
Pause
If exist a:\%#@%.a28 Goto d29ok
Goto TEST29
:d29ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a28 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd29
Goto test30
:erd29
Cls
Echo Hubo un error con el disco 29, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format29
If errorlevel 1 Goto reCopy29
:format29
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd29
:reCopy29
Cls
Echo Volviendo a copiar disco 29.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a28 a:\%#@%.a28
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d29ok

:test30
If not exist %temp%\alx_ll_f.a29 Goto todojoya
Cls
Echo Proceda a insertar disco 30 para que sea verificado.
Pause
If exist a:\%#@%.a29 Goto d30ok
Goto TEST30
:d30ok
Echo Verificando diskette, por favor espere...
Call arj t a:\%#@%.a29 <%temp%\cletra_n.tmp >nul
If errorlevel 1 Goto erd30
Goto test31
:erd30
Cls
Echo Hubo un error con el disco 30, se deber  volver a copiar.
Echo Si desea utilizar un disco nuevo, INSERTELO AHORA y presione la "A".
Echo Si desea formatear el actual para volver a intentarlo, presione la "B".
Call ask "Su selecci¢n? ", AB
If errorlevel 2 Goto format30
If errorlevel 1 Goto reCopy30
:format30
call axformat a: /u /autotest
IF "%OS%"=="Windows_NT" call axformat a: /u <%temp%\cletra_n.tmp
If errorlevel 1 Echo.
If errorlevel 1 Echo ***** ERROR DE FORMATEO *****.  Tal vez el disco se encuentre muy da¤ado.
If errorlevel 1 Echo.
If errorlevel 1 Pause
If errorlevel 1 Goto erd30
:reCopy30
Cls
Echo Volviendo a copiar disco 30.....
call axformat a: /q /autotest <%temp%\cletra_n.tmp >nul
IF "%OS%"=="Windows_NT" call axformat a: /q <%temp%\cletra_n.tmp >nul
Copy %temp%\alx_ll_f.a29 a:\%#@%.a29
Cls
Echo.
Echo.
Echo.
Echo QUITE el disco y VUELVA a insertarlo (es muy importante para poder probarlo)
Echo HAGALO ahora y presione cualquier tecla.......
Pause >nul
Goto d30ok

:test31


Rem *** Area de bucles de repetici¢n mediante uso de variables de entorno ***


rem *** Fin de bucles ***

:todojoya
rem ***************
If exist a:\instalar.bat Goto skipcfib
Echo @Echo off >a:\instalar.bat
Echo Cls>>a:\instalar.bat
Echo Echo Este proceso instalar  el contenido de este set de diskettes en la carpeta>>a:\instalar.bat
Echo Echo %#@% de la unidad C:.>>a:\instalar.bat
Echo Echo.>>a:\instalar.bat
Echo Echo Presione CTRL + C si desea cancelar la instalaci¢n en este momento, o bien>>a:\instalar.bat
Echo Pause>>a:\instalar.bat
Echo Cls>>a:\instalar.bat
Echo IF EXIST C:\tmp_x_ll.tmp\tmpipcad.bat GOTO NOCREAR>>a:\instalar.bat
Echo MD C:\tmp_x_ll.tmp>>a:\instalar.bat
Echo :nocrear>>a:\instalar.bat
Echo COPY tmpipcad.bat C:\tmp_x_ll.tmp>>a:\instalar.bat
Echo C:>>a:\instalar.bat
Echo CD C:\tmp_x_ll.tmp>>a:\instalar.bat
Echo tmpipcad.bat>>a:\instalar.bat
Copy %temp%\tmpipcad.bat a:>nul
rem ***************
:skipcfib
Cls
Echo El testeo result¢ bien.

Echo ­El proceso ha finalizado satisfactoriamente!.
Echo.
Goto fin

:final
Cls
Echo.
Echo Proceso terminado.
Echo.

:fin
