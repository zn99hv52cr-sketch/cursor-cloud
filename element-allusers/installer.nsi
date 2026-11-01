; Per-machine installer for the official Element Desktop build.
; Installs into Program Files and registers shortcuts for every user.
; The public Element Setup.exe is Squirrel and installs only for the current user.

Unicode true
ManifestDPIAware true
SetCompressor zlib
RequestExecutionLevel admin
CRCCheck on
SetOverwrite on

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

!ifndef ICON_FILE
  !error "Pass -DICON_FILE=element.ico"
!endif

!ifndef APP_VERSION
  !define APP_VERSION "1.12.30"
!endif
!ifndef PAYLOAD_DIR
  !define PAYLOAD_DIR "payload"
!endif
!ifndef OUTFILE
  !define OUTFILE "Element-${APP_VERSION}-AllUsers-x64.exe"
!endif

!define APP_NAME "Element"
!define APP_EXE "Element.exe"
!define UNINSTALL_REG "Software\Microsoft\Windows\CurrentVersion\Uninstall\Element"
!define APP_PATHS_REG "Software\Microsoft\Windows\CurrentVersion\App Paths\Element.exe"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey HKLM "${UNINSTALL_REG}" "InstallLocation"
ShowInstDetails show
ShowUninstDetails show
BrandingText "${APP_NAME} ${APP_VERSION} — для всех пользователей"

!define MUI_ABORTWARNING
!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
!define MUI_WELCOMEPAGE_TITLE "Element ${APP_VERSION}"
!define MUI_WELCOMEPAGE_TEXT "$(WELCOME_TEXT)"
!define MUI_FINISHPAGE_TITLE "Element установлен"
!define MUI_FINISHPAGE_TEXT "$(FINISH_TEXT)"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "English"

LangString WELCOME_TEXT ${LANG_RUSSIAN} "Эта сборка ставит Element ${APP_VERSION} для всех пользователей компьютера.$\r$\n$\r$\nФайлы: Program Files\Element$\r$\nЯрлыки: общее меню Пуск и общий рабочий стол$\r$\nПротоколы element:// и io.element.desktop:// регистрируются в HKLM.$\r$\n$\r$\nНужны права администратора. Обычный Element Setup.exe ставит программу только в профиль текущего пользователя. Автообновление Squirrel отключено: обновление делает администратор, запустив новый установщик."
LangString WELCOME_TEXT ${LANG_ENGLISH} "This setup installs Element ${APP_VERSION} for every user on this computer.$\r$\n$\r$\nFiles go to Program Files\Element. Shortcuts are created in the common Start Menu and the public desktop. The element:// and io.element.desktop:// protocols are registered in HKLM.$\r$\n$\r$\nAdministrator rights are required. The official Element Setup.exe installs only for the current user. Squirrel auto-update is not enabled; an administrator installs updates by running a newer setup."
LangString FINISH_TEXT ${LANG_RUSSIAN} "Element установлен для всех пользователей. Запускайте его из меню Пуск под обычной учётной записью, не из-под администратора.$\r$\n$\r$\nТихая установка: Element-${APP_VERSION}-AllUsers-x64.exe /S$\r$\nСвой каталог: /D=C:\Apps\Element (параметр /D должен быть последним)."
LangString FINISH_TEXT ${LANG_ENGLISH} "Element is installed for all users. Start it from the Start Menu as a normal user.$\r$\n$\r$\nSilent install: Element-${APP_VERSION}-AllUsers-x64.exe /S$\r$\nCustom directory: /D=C:\Apps\Element (/D must be the last parameter)."

VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "Element"
VIAddVersionKey "CompanyName" "Element"
VIAddVersionKey "FileDescription" "Element all-users installer"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "Element Desktop is published by Element. This wrapper installs the official unmodified ${APP_VERSION} build for all users."
VIAddVersionKey "OriginalFilename" "Element-${APP_VERSION}-AllUsers-x64.exe"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "Нужна 64-битная Windows. / 64-bit Windows is required."
    Abort
  ${EndIf}
  SetRegView 64
  SetShellVarContext all
FunctionEnd

Function un.onInit
  SetRegView 64
  SetShellVarContext all
FunctionEnd

Section "Element"
  SectionIn RO

  ; A new install must replace a running copy. taskkill exits 128 when Element is not running.
  ExecWait 'taskkill /F /IM "${APP_EXE}" /T'

  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD_DIR}/*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0 SW_SHOWNORMAL "" "Element"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\Удалить ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0 SW_SHOWNORMAL "" "Element"

  WriteRegStr HKLM "${UNINSTALL_REG}" "DisplayName" "Element"
  WriteRegStr HKLM "${UNINSTALL_REG}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINSTALL_REG}" "Publisher" "Element"
  WriteRegStr HKLM "${UNINSTALL_REG}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTALL_REG}" "DisplayIcon" "$INSTDIR\${APP_EXE},0"
  WriteRegStr HKLM "${UNINSTALL_REG}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "${UNINSTALL_REG}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNINSTALL_REG}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTALL_REG}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKLM "${UNINSTALL_REG}" "EstimatedSize" "$0"

  WriteRegStr HKLM "${APP_PATHS_REG}" "" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKLM "${APP_PATHS_REG}" "Path" "$INSTDIR"

  Call RegisterProtocols
SectionEnd

Function RegisterProtocol
  ; $0 = scheme
  WriteRegStr HKLM "Software\Classes\$0" "" "URL:Element"
  WriteRegStr HKLM "Software\Classes\$0" "URL Protocol" ""
  WriteRegStr HKLM "Software\Classes\$0\DefaultIcon" "" "$INSTDIR\${APP_EXE},0"
  WriteRegStr HKLM "Software\Classes\$0\shell" "" "open"
  WriteRegStr HKLM "Software\Classes\$0\shell\open\command" "" '"$INSTDIR\${APP_EXE}" "%1"'
FunctionEnd

Function RegisterProtocols
  Push $0
  StrCpy $0 "element"
  Call RegisterProtocol
  StrCpy $0 "io.element.desktop"
  Call RegisterProtocol
  Pop $0
FunctionEnd

Function un.RemoveProtocol
  ; $0 = scheme. Remove the machine key only when it still points at this install.
  ReadRegStr $1 HKLM "Software\Classes\$0\shell\open\command" ""
  StrCpy $2 '"$INSTDIR\${APP_EXE}" "%1"'
  ${If} $1 == $2
    DeleteRegKey HKLM "Software\Classes\$0"
  ${EndIf}
FunctionEnd

Section "Uninstall"
  ExecWait 'taskkill /F /IM "${APP_EXE}" /T'

  ${If} "$INSTDIR" == ""
  ${OrIf} "$INSTDIR" == "$PROGRAMFILES64"
  ${OrIfNot} ${FileExists} "$INSTDIR\${APP_EXE}"
    Abort
  ${EndIf}

  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Удалить ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"

  DeleteRegKey HKLM "${UNINSTALL_REG}"
  DeleteRegKey HKLM "${APP_PATHS_REG}"

  Push $0
  Push $1
  Push $2
  StrCpy $0 "element"
  Call un.RemoveProtocol
  StrCpy $0 "io.element.desktop"
  Call un.RemoveProtocol
  Pop $2
  Pop $1
  Pop $0

  RMDir /r "$INSTDIR"
SectionEnd
