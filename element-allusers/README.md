# Element для всех пользователей (Windows x64)

Официальный `Element Setup.exe` — установщик Squirrel. Он ставит Element только в профиль текущего пользователя (`%LOCALAPPDATA%\element-desktop`). Машинный MSI, который Element собирает с `perMachine: true` и кладёт в `Program Files`, публично не раздаётся: его получают подписчики Element Server Suite.

Этот каталог собирает NSIS-установщик **для всех пользователей** из немодифицированных файлов официальной сборки.

## Что делает установщик

- Требует права администратора и 64-битную Windows.
- Копирует Element в `C:\Program Files\Element` (каталог можно сменить).
- Кладёт ярлыки в общее меню Пуск и на общий рабочий стол.
- Пишет удаление в `HKLM\...\Uninstall\Element`, поэтому программа видна в «Приложения и возможности» для всех.
- Регистрирует протоколы `element://` и `io.element.desktop://` в `HKLM\Software\Classes`.
- Не включает автообновление Squirrel. Обновление ставит администратор, запустив новый установщик. Данные пользователя остаются в `%APPDATA%\Element`.

Версия по умолчанию: **1.12.30**. Официальный файл сверяется с SHA-256 из манифеста winget `Element.Element`:

`b9ac9617acfa667eb5470e67e5db744d3b595b35c285100a53ad17719f7cc6d3`

Исходный код Element Desktop этой версии: <https://github.com/element-hq/element-web/tree/v1.12.30> (AGPL-3.0-only OR GPL-3.0-only OR LicenseRef-Element-Commercial). Файлы приложения не изменяются.

Сборщик не подписывает установщик сертификатом Element. Windows SmartScreen может запросить подтверждение. Сам `Element.exe` внутри остаётся официальным файлом из подписанного Squirrel-пакета.

## Сборка

Нужны `curl`, `python3` с Pillow, `makensis` (пакет `nsis`) и `sha256sum`.

```bash
./element-allusers/build.sh
```

Результат: `element-allusers/dist/Element-1.12.30-AllUsers-x64.exe`.

Готовый установщик этой ревизии уже лежит в `element-allusers/release/` тремя частями (GitHub не принимает файл больше 100 МиБ). На Windows в этой папке:

```bat
join.bat
```

Скрипт собирает `Element-1.12.30-AllUsers-x64.exe`. SHA-256 целого файла:

`8a8f23e0859421914175a1f5632b856012bb019593d49ad57c9866def4f3d278`

## Установка

Интерактивно: запустить exe от администратора.

Тихо, в каталог по умолчанию:

```bat
Element-1.12.30-AllUsers-x64.exe /S
```

Тихо, в свой каталог (`/D` — последний параметр, без кавычек):

```bat
Element-1.12.30-AllUsers-x64.exe /S /D=C:\Apps\Element
```

Удаление:

```bat
"%ProgramFiles%\Element\Uninstall.exe" /S
```
