@ECHO OFF
CLS
ECHO.
ECHO Instalando, por favor espere...
ECHO.

If exist %windir%\Escritorio\nul Copy llevar.bat %windir%\Escritorio >nul
Echo prueba >"%userprofile%\escritorio\alxt-t-dedw2k.alx"
If exist "%userprofile%\escritorio\alxt-t-dedw2k.alx" Copy llevar.bat "%userprofile%\escritorio"
If exist "%userprofile%\escritorio\alxt-t-dedw2k.alx" Del "%userprofile%\escritorio\alxt-t-dedw2k.alx"
IF EXIST C:\UTILIDAD\ARJ.EXE COPY ARJ.EXE C:\UTILIDAD
COPY *.EXE %WINDIR%
COPY LLEVAR.BAT %WINDIR%

CLS
ECHO.
ECHO A continuaci¢n, se abrir  una ventana. En la misma, deber s hacer CLIC
ECHO con el bot¢n derecho al archivo LLEVARSE y elegir la opci¢n INSTALAR.
ECHO Al hacerlo, finalizar  la instalaci¢n. Despu‚s de eso, cada vez que
ECHO quieras llevarte una carpeta, simplemente podr s hacerle CLIC con el
ECHO bot¢n derecho y elegir "LLEVARSE ESTO EN DISKETTES". Si quieres llevarte
ECHO solo UN archivo, deber s copiarlo a una carpeta y hacer lo mencionado.
ECHO.
Pause
START .
CLS
Echo.
Echo                       ¨ COMO SE USA EL "LLEVAR" ?
Echo.
Echo La forma m s sencilla de usar el LLEVAR es mediante el nuevo icono que se
Echo encuentra ahora en tu escritorio. Simplemente, arrastra la CARPETA que te
Echo quieres llevar sobre el icono LLEVAR, y listo!
Echo.
Echo Tambi‚n puedes hacerle clic derecho a la CARPETA que quieres llevarte, y
Echo elegir "LLEVARSE ESTO EN DISKETTES". ­Mejor a£n!
Echo.
Echo.
Echo Y si lo usas bajo DOS, simplemente metete dentro del directorio que quer‚s
Echo transportar, y escrib¡ "LLEVAR PACMAN", o "LLEVAR PIRULO", o el nombre que
Echo quieras. ­As¡ de f cil!
Echo.
PAUSE
EXIT
